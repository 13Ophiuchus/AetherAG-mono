import Flow
import CryptoKit
import Foundation

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
        let chainID = FlowChainIDResolver.resolve(asset.chainConfig)
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
        let chainID = FlowChainIDResolver.resolve(asset.chainConfig)

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
                    FlowArgument(type: "Address", value: toAddress.hex),
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
        let chainID = FlowChainIDResolver.resolve(chain)
        let flowClient = Flow()
        await flowClient.configure(chainID: chainID, accessAPI: flowClient.createHTTPAccessAPI(chainID: chainID))

        do {
            let latestHeight = try await flowClient.accessAPI.getLatestBlockHeader(blockStatus: .sealed).height
            let lookbackRange: UInt64 = 5000
            let startHeight = latestHeight > lookbackRange ? latestHeight - lookbackRange : 0
            let range = startHeight ... latestHeight

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
                            FlowArgument(type: "Address", value: watchedAddress),
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

    func executeScript(
        _ script: String,
        arguments: [Flow.Cadence.FValue],
        on chain: ChainConfig
    ) async throws -> Flow.Cadence.FValue {
        logger.info("Executing Flow script on \(chain.name)")

        let chainID = FlowChainIDResolver.resolve(chain)
        let flowClient = Flow()
        await flowClient.configure(chainID: chainID, accessAPI: flowClient.createHTTPAccessAPI(chainID: chainID))

        do {
            let response = try await flowClient.accessAPI.executeScriptAtLatestBlock(
                cadence: script,
                arguments: arguments,
                blockStatus: .final
            )
            guard let value = response.fields?.value else {
                throw WalletError.signingFailed("Flow script response did not contain a decodable value")
            }
            return value
        } catch let error as WalletError {
            throw error
        } catch {
            throw WalletError.signingFailed("Flow script execution failed: \(error.localizedDescription)")
        }
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
            Flow.Argument(value: .address(to)),
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

    func sign(signableData: Data, transaction _: Flow.Transaction?) async throws -> Data {
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

// MARK: - FlowChainIDResolver

/// Maps a shared `ChainConfig` to the Flow SDK's `Flow.ChainID`, following the
/// convention that any non-testnet active network resolves to mainnet.
/// Extracted as a pure, network-independent helper (was previously duplicated
/// inline across getBalance/send/getTransactionHistory/executeScript) so the
/// mapping logic can be unit tested without a live Flow client.
enum FlowChainIDResolver {
    static func resolve(_ chain: ChainConfig) -> Flow.ChainID {
        chain.activeNetwork == .testnet ? .testnet : .mainnet
    }
}

// MARK: - Flow Account Creation & Reset (appended)

import Flow

extension KeyManagerActor {

    /// Derives the P256 public key from the stored master key, matching the
    /// same key material used by signFlowTransactionEnvelope/signFlowMessage.
    public func flowP256PublicKeyHex(keyIdentifier: String = "masterKey") throws -> String {
        guard let rawMasterKey = try retrievePrivateKey(for: keyIdentifier) else {
            throw WalletError.keychainError("Master key not found")
        }
        let masterKey = rawMasterKey.count >= 32 ? Data(rawMasterKey.prefix(32)) : rawMasterKey
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: masterKey)
        let uncompressed = signingKey.publicKey.rawRepresentation
        return uncompressed.toHexString()
    }

    /// Creates a brand-new Flow account on-chain, funded/signed by an issuer
    /// account, using this wallet's own master-key-derived P256 public key.
    /// On success, persists the new address via storeFlowAddress(_:).
    public func createFlowAccount(
        issuerConfig: FlowIssuerConfig,
        flowGateway: any FlowGatewayProtocol,
        network: Flow.ChainID,
        keyIdentifier: String = "masterKey"
    ) async throws -> String {
        let publicKeyHex = try flowP256PublicKeyHex(keyIdentifier: keyIdentifier)
        let signer = FlowIssuerSigner(issuerConfig: issuerConfig)

        guard let scriptURL = Bundle.module.url(
            forResource: "create_user_account",
            withExtension: "cdc",
            subdirectory: "Cadence"
        ) else {
            throw WalletError.chainConfigurationError("Missing create_user_account.cdc resource")
        }
        let script = try Data(contentsOf: scriptURL)

        let arguments: [Flow.Argument] = [
            Flow.Argument(value: .string(publicKeyHex)),
            Flow.Argument(value: .uint8(1)),
            Flow.Argument(value: .uint8(3)),
            Flow.Argument(value: .ufix64(Decimal(string: "1000.0") ?? 1000))
        ]

        let txID = try await flowGateway.sendTransaction(
            script: script,
            arguments: arguments,
            gasLimit: 200,
            proposalKey: issuerConfig.proposalKey,
            payer: issuerConfig.address,
            authorizers: [issuerConfig.address],
            envelopeSigner: signer
        )

        var result = try await flowGateway.transactionResult(id: txID)
        var delayNanoseconds: UInt64 = 500_000_000
        let maxDelayNanoseconds: UInt64 = 8_000_000_000
        let deadline = Date().addingTimeInterval(90)
        while result.status != .sealed && Date() < deadline {
            try await Task.sleep(nanoseconds: delayNanoseconds)
            result = try await flowGateway.transactionResult(id: txID)
            delayNanoseconds = min(delayNanoseconds * 2, maxDelayNanoseconds)
        }

        guard result.status == .sealed else {
            throw WalletError.signingFailed("Flow account creation did not seal in time")
        }
        guard let event = result.events.first(where: { $0.type.contains("AccountCreated") }) else {
            throw WalletError.signingFailed("Account creation sealed but no AccountCreated event found")
        }
        guard let newAddressHex: String = event.getField("address") else {
            throw WalletError.signingFailed("AccountCreated event found but missing 'address' field")
        }

        try storeFlowAddress(newAddressHex)
        return newAddressHex
    }

    /// Wipes the locally stored Flow address, forcing the next call to
    /// createFlowAccount to provision an entirely fresh on-chain account.
    /// Does NOT touch the master key — use resetMasterKey() for a full reset.
    public func resetFlowAddress() throws {
        try deletePrivateKey(for: "flowAddress")
    }

    /// Generates a brand-new mnemonic/master key, discarding the old one.
    /// Destructive: invalidates Solana/Bitcoin/Flow addresses derived from
    /// the old master key. Use only for confirmed key-compromise scenarios.
    public func resetMasterKey(requiresBiometrics: Bool = true) throws -> [String] {
        let newMnemonic = try generateMnemonic()
        let newMasterKey = try generateMasterPrivateKey(from: newMnemonic)
        try deletePrivateKey(for: "masterKey")
        try deletePrivateKey(for: "flowAddress")
        try storePrivateKey(newMasterKey, for: "masterKey", requiresBiometrics: requiresBiometrics)
        return newMnemonic
    }
}
