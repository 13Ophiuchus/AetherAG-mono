import Foundation
import Flow

// MARK: - Cadence query for FlowToken balance

// Borrows the account's public FlowToken balance capability and returns its balance.
// Uses the idiomatic Cadence `borrow()` pattern: a live reference into account storage
// rather than a copy, so this respects Cadence's resource-linearity guarantees.
private struct GetFlowBalanceQuery: CadenceTargetType {
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
		logger.warning("Flow transfer not yet implemented; requires FlowSigner bridge to KeyManagerActor.")
		throw WalletError.unsupportedOperation("Flow token transfer not yet implemented")
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting Flow transaction history for \(chain.name)")
		logger.warning("Flow transaction history requires an indexer integration; not yet implemented.")
		return []
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
