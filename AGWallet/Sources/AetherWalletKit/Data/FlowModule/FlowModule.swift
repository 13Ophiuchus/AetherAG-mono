import Foundation
import Flow

// MARK: - Cadence query for FlowToken balance

struct GetFlowBalanceQuery: CadenceTargetType {
	let address: Flow.Address

	var type: CadenceType { .query }
	var returnType: Decodable.Type { String.self }
	var arguments: [Flow.Argument] { [Flow.Argument(value: .address(address))] }

	var cadenceBase64: String {
		let script = """
		import FungibleToken from 0xf233dcee88fe0abe
		import FlowToken from 0x1654653399040a61

		access(all) fun main(address: Address): UFix64 {
		    let account = getAccount(address)
		    let vaultRef = account.capabilities
		        .get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
		        .borrow()
		        ?? panic("Could not borrow FlowToken balance capability")
		    return vaultRef.balance
		}
		"""
		return Data(script.utf8).base64EncodedString()
	}
}

final class FlowModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.FlowModule")

	init(keyManager: KeyManagerActor) {
		self.keyManager = keyManager
	}

	func getReceiveAddress(for chain: ChainConfig) async throws -> String {
		logger.info("Getting receive address for \(chain.name)")
		guard let addressHex = try await keyManager.flowAddress() else {
			throw WalletError.keychainError(
				"Flow address not found; call storeFlowAddress(_:) after account creation"
			)
		}
		return Flow.Address(hex: addressHex).hex
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting Flow balance for \(asset.symbol)")
		guard let addressHex = try await keyManager.flowAddress() else {
			throw WalletError.keychainError("Flow address not found; call storeFlowAddress(_:) before querying balance")
		}
		let flowAddress = Flow.Address(hex: addressHex)
		let chainID: Flow.ChainID = asset.chainConfig.activeNetwork == .testnet ? .testnet : .mainnet
		let flowClient = Flow()
		do {
			let balanceString: String = try await flowClient.query(
				GetFlowBalanceQuery(address: flowAddress),
				chainID: chainID
			)
			guard let balance = Double(balanceString) else {
				throw WalletError.signingFailed("Unable to parse Flow balance response: \(balanceString)")
			}
			return balance
		} catch let error as WalletError {
			throw error
		} catch {
			throw WalletError.signingFailed("Flow balance query failed: \(error.localizedDescription)")
		}
	}

	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")

		guard let addressHex = try await keyManager.flowAddress() else {
			throw WalletError.keychainError("Flow address not found; call storeFlowAddress(_:) before sending")
		}
		let fromAddress = Flow.Address(hex: addressHex)
		let toAddress = Flow.Address(hex: recipientAddress)
		let keyIndex = try await keyManager.flowKeyIndex()
		let chainID: Flow.ChainID = asset.chainConfig.activeNetwork == .testnet ? .testnet : .mainnet

		let signer = KeyManagerFlowSigner(address: fromAddress, keyIndex: keyIndex, keyManager: keyManager)
		let target = TransferFlowTokenTarget(to: toAddress, amount: amount)

		do {
			let flowClient = Flow()
			let txId = try await flowClient.sendTransaction(target, signers: [signer], chainID: chainID)

			logger.info("Successfully submitted Flow transaction with ID: \(txId.hex)")

			let unifiedTx = FlowTransaction(
				id: txId.hex,
				script: target.cadenceBase64,
				arguments: [
					FlowArgument(type: "UFix64", value: String(amount)),
					FlowArgument(type: "Address", value: toAddress.hex)
				],
				proposer: fromAddress.hex,
				authorizers: [fromAddress.hex],
				payer: fromAddress.hex,
				gasLimit: 999,
				status: .pending,
				timestamp: Date()
			)
			return .flow(unifiedTx)
		} catch let error as WalletError {
			throw error
		} catch {
			throw WalletError.signingFailed("Flow transaction failed: \(error.localizedDescription)")
		}
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting Flow transaction history for \(chain.name)")

		guard let addressHex = try await keyManager.flowAddress() else {
			throw WalletError.keychainError("Flow address not found; call storeFlowAddress(_:) before querying history")
		}
		let watchedAddress = Flow.Address(hex: addressHex).hex
		let chainID: Flow.ChainID = chain.activeNetwork == .testnet ? .testnet : .mainnet
		let flowClient = Flow()
		await flowClient.configure(chainID: chainID, accessAPI: flowClient.createHTTPAccessAPI(chainID: chainID))

		do {
			let latestHeight = try await flowClient.accessAPI.getLatestBlockHeader(blockStatus: .sealed).height
			let lookbackRange: UInt64 = 5_000
			let startHeight = latestHeight > lookbackRange ? latestHeight - lookbackRange : 0
			let range = startHeight...latestHeight

			let depositedType = FlowTokenEventType.deposited(chainID: chainID)
			let withdrawnType = FlowTokenEventType.withdrawn(chainID: chainID)

			async let depositedResults = flowClient.accessAPI.getEventsForHeightRange(type: depositedType, range: range)
			async let withdrawnResults = flowClient.accessAPI.getEventsForHeightRange(type: withdrawnType, range: range)

			let (deposited, withdrawn) = try await (depositedResults, withdrawnResults)
			let allEvents = deposited + withdrawn

			var transactions: [UnifiedTransaction] = []
			for result in allEvents {
				for event in result.events {
					let isDeposit = event.type == depositedType
					let toField: String? = event.getField("to")
					let fromField: String? = event.getField("from")

					guard FlowTransactionHistoryMatcher.matches(
						isDeposit: isDeposit,
						toField: toField,
						fromField: fromField,
						watchedAddress: watchedAddress
					) else { continue }

					let amount: String = event.getField("amount") ?? "0.0"

					let unifiedTx = FlowTransaction(
						id: event.transactionId.hex,
						script: event.type,
						arguments: [
							FlowArgument(type: "UFix64", value: amount),
							FlowArgument(type: "Address", value: watchedAddress)
						],
						proposer: isDeposit ? (fromField ?? "unknown") : watchedAddress,
						authorizers: [watchedAddress],
						payer: watchedAddress,
						gasLimit: 0,
						status: .committed,
						timestamp: Date()
					)
					transactions.append(.flow(unifiedTx))
				}
			}
			return transactions
		} catch let error as WalletError {
			throw error
		} catch {
			throw WalletError.signingFailed("Flow transaction history query failed: \(error.localizedDescription)")
		}
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on Flow")
		return try await keyManager.signFlowMessage(message, chain: chain)
	}

	// MARK: - Flow Specific Methods

	func executeScript(_ script: String, arguments: [Flow.Cadence.FValue]) async throws -> Flow.Cadence.FValue {
		logger.info("Executing Flow script")
		logger.warning("Flow script execution bridge not yet implemented for current Flow SDK.")
		throw WalletError.unsupportedOperation("Flow script execution not yet implemented")
	}
}

// MARK: - TransferFlowTokenTarget

/// Cadence transaction target for a plain FlowToken transfer, following the
/// same `CadenceTargetType` pattern as `GetFlowBalanceQuery` above.
struct TransferFlowTokenTarget: CadenceTargetType {
	let to: Flow.Address
	let amount: Double

	var type: CadenceType { .transaction }
	var returnType: Decodable.Type { String.self }
	var arguments: [Flow.Argument] {
		[
			Flow.Argument(value: .ufix64(Decimal(amount))),
			Flow.Argument(value: .address(to))
		]
	}

	var cadenceBase64: String {
		let script = """
		import FungibleToken from 0xf233dcee88fe0abe
		import FlowToken from 0x1654653399040a61

		transaction(amount: UFix64, to: Address) {
		    let sentVault: @{FungibleToken.Vault}
		    prepare(signer: auth(BorrowValue) &Account) {
		        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
		            ?? panic("Could not borrow reference to the owner's Vault!")
		        self.sentVault <- vaultRef.withdraw(amount: amount)
		    }
		    execute {
		        let recipient = getAccount(to)
		        let receiverRef = recipient.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
		            .borrow()
		            ?? panic("Could not borrow receiver reference to the recipient's Vault")
		        receiverRef.deposit(from: <-self.sentVault)
		    }
		}
		"""
		return Data(script.utf8).base64EncodedString()
	}
}

// MARK: - KeyManagerFlowSigner

/// Bridges `KeyManagerActor`'s stored master key into the `Flow` SDK's
/// `FlowSigner` protocol so transactions can be signed without exposing
/// raw key material outside the actor boundary.
struct KeyManagerFlowSigner: FlowSigner {
	var address: Flow.Address
	var keyIndex: Int
	let keyManager: KeyManagerActor

	func sign(signableData: Data, transaction: Flow.Transaction?) async throws -> Data {
		try await keyManager.signFlowTransactionEnvelope(signableData)
	}
}

// MARK: - FlowTokenEventType

/// Resolves canonical FlowToken contract event type identifiers per Flow chain,
/// following the `A.<address>.FlowToken.<EventName>` Cadence event naming convention.
/// Pulled out as a pure, network-independent helper so contract-address selection
/// can be unit tested without hitting the Flow access API.
enum FlowTokenEventType {
	static func contractAddress(chainID: Flow.ChainID) -> String {
		chainID == .testnet ? "7e60df042a9c0868" : "1654653399040a61"
	}

	static func deposited(chainID: Flow.ChainID) -> String {
		"A.\(contractAddress(chainID: chainID)).FlowToken.TokensDeposited"
	}

	static func withdrawn(chainID: Flow.ChainID) -> String {
		"A.\(contractAddress(chainID: chainID)).FlowToken.TokensWithdrawn"
	}
}

// MARK: - FlowTransactionHistoryMatcher

/// Determines whether a FlowToken transfer event pertains to the watched wallet
/// address. `TokensDeposited` reliably populates `to`; `TokensWithdrawn` reliably
/// populates `from`. Extracted as a pure function for unit testing without needing
/// real Cadence-encoded event payloads.
enum FlowTransactionHistoryMatcher {
	static func matches(
		isDeposit: Bool,
		toField: String?,
		fromField: String?,
		watchedAddress: String
	) -> Bool {
		isDeposit ? toField == watchedAddress : fromField == watchedAddress
	}
}
