import Foundation
import SolanaSwift
import Foundation
import Testing
@testable import AetherWalletKit

@Suite("SolanaModule")
struct SolanaModuleTests {

    private func makeModule() -> SolanaModule {
        SolanaModule(keyManager: KeyManagerActor())
    }

    private func makeModule(
        withStoredMasterKey keyManager: KeyManagerActor,
        rpcClient: SolanaRPCClientProtocol
    ) -> SolanaModule {
        SolanaModule(keyManager: keyManager, rpcClientOverride: rpcClient)
    }

    @Test("getBalance fails with keychainError when no master key is stored")
    func testGetBalance() async throws {
        let solanaModule = makeModule()
        let asset = CryptoAsset.mockSolana()

        do {
            _ = try await solanaModule.getBalance(for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for Solana getBalance")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

    @Test("send fails with keychainError when no master key is stored")
    func testSendTransaction() async throws {
        let solanaModule = makeModule()
        let asset = CryptoAsset.mockSolana()
        let amount = 1.5
        let recipient = "So11111111111111111111111111111111111111112"

        do {
            _ = try await solanaModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for native SOL send")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

@Test("send broadcasts a real native SOL transfer using the injected mock RPC client")
    func testSendTransactionHappyPath() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let masterKey = Data(repeating: 0x42, count: 32)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)

        // Use the same known-good, correctly-decoding base58 blockhash and
        // recipient address already proven valid in KeyManagerActorSolanaTests,
        // since Transaction.serialize() requires an exact 32-byte blockhash.
        let mockClient = MockSolanaRPCClient(
            blockhashToReturn: "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud",
            transactionIdToReturn: "5VfYmGC1CLK1ynr6oGuBGbmNjZsFHunbP7L1rQpKcz2h"
        )

        let solanaModule = makeModule(withStoredMasterKey: keyManager, rpcClient: mockClient)
        let asset = CryptoAsset.mockSolana()
        let recipient = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"

        let result = try await solanaModule.send(amount: 0.001, to: recipient, for: asset)

        guard case let .solana(signedTx) = result else {
            Issue.record("Expected .solana(UnifiedTransaction) case")
            return
        }

        #expect(!signedTx.signature.isEmpty)
        #expect(signedTx.recentBlockhash == "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud")
        #expect(signedTx.instructions.count == 1)
        #expect(mockClient.lastSentTransactionBase64 != nil)
        #expect(mockClient.getRecentBlockhashCallCount == 1)
        #expect(mockClient.sendTransactionCallCount == 1)
    }

        @Test("signMessage fails with unsupportedOperation before Solana message signing is implemented")
    func testSignMessage() async throws {
        let solanaModule = makeModule()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockSolanaChain()

        do {
            _ = try await solanaModule.signMessage(message, on: chain)
            Issue.record("Expected unsupportedOperation for Solana message signing")
        } catch WalletError.unsupportedOperation(let message) {
            #expect(message.contains("Solana message signing"))
        }
    }

    @Test("getBalance returns native SOL balance converted from lamports using the injected mock RPC client")
    func testGetBalanceHappyPath() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let masterKey = Data(repeating: 0x42, count: 32)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)

        let mockClient = MockSolanaRPCClient(
            blockhashToReturn: "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud",
            transactionIdToReturn: "5VfYmGC1CLK1ynr6oGuBGbmNjZsFHunbP7L1rQpKcz2h"
        )
        mockClient.balanceToReturn = 1_500_000_000

        let solanaModule = makeModule(withStoredMasterKey: keyManager, rpcClient: mockClient)
        let asset = CryptoAsset.mockSolana()

        let balance = try await solanaModule.getBalance(for: asset)

        #expect(balance == 1.5)
    }

    @Test("getTransactionHistory maps signatures and transaction info into UnifiedTransaction entries")
    func testGetTransactionHistoryHappyPath() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let masterKey = Data(repeating: 0x42, count: 32)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)

        let mockClient = MockSolanaRPCClient(
            blockhashToReturn: "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud",
            transactionIdToReturn: "5VfYmGC1CLK1ynr6oGuBGbmNjZsFHunbP7L1rQpKcz2h"
        )

        let signature = "5VfYmGC1CLK1ynr6oGuBGbmNjZsFHunbP7L1rQpKcz2h"
        mockClient.signaturesToReturn = [
            SignatureInfo(signature: signature)
        ]

        let transactionJSON = """
        {
            "blockTime": 1700000000,
            "slot": 12345,
            "meta": {
                "fee": 5000
            },
            "transaction": {
                "signatures": ["\(signature)"],
                "message": {
                    "accountKeys": [],
                    "instructions": [],
                    "recentBlockhash": "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud"
                }
            }
        }
        """
        let transactionInfo = try JSONDecoder().decode(
            TransactionInfo.self,
            from: Data(transactionJSON.utf8)
        )
        mockClient.transactionsBySignature[signature] = transactionInfo

        let solanaModule = makeModule(withStoredMasterKey: keyManager, rpcClient: mockClient)
        let chain = ChainConfig.mockSolanaChain()

        let history = try await solanaModule.getTransactionHistory(for: chain)

        #expect(history.count == 1)
        guard case let .solana(tx) = history[0] else {
            Issue.record("Expected .solana(UnifiedTransaction) case")
            return
        }
        #expect(tx.signature == signature)
        #expect(tx.fee == 0.000005)
        #expect(tx.slot == 12345)
    }
}

// MARK: - Mocks

extension ChainConfig {
    static func mockSolanaChain() -> ChainConfig {
        return ChainConfig(
            chainId: "solana",
            name: "Solana",
            type: .solana,
            rpcEndpoints: [URL(string: "https://api.mainnet-beta.solana.com")!],
            derivationPath: "m/44'/501'/0'/0'",
            nativeAssetSymbol: "SOL"
        )
    }
}

// MARK: - Mock RPC Client

// Records calls and returns canned responses so send() can be tested
// end-to-end without any network I/O or risk of broadcasting to mainnet.
final class MockSolanaRPCClient: SolanaRPCClientProtocol {
    let blockhashToReturn: String
    let transactionIdToReturn: String
    var balanceToReturn: UInt64 = 0
    var signaturesToReturn: [SignatureInfo] = []
    var transactionsBySignature: [String: TransactionInfo] = [:]

    private(set) var getRecentBlockhashCallCount = 0
    private(set) var sendTransactionCallCount = 0
    private(set) var lastSentTransactionBase64: String?

    init(blockhashToReturn: String, transactionIdToReturn: String) {
        self.blockhashToReturn = blockhashToReturn
        self.transactionIdToReturn = transactionIdToReturn
    }

    func getRecentBlockhash(commitment: Commitment?) async throws -> String {
        getRecentBlockhashCallCount += 1
        return blockhashToReturn
    }

    func getBalance(account: String, commitment: Commitment?) async throws -> UInt64 {
        balanceToReturn
    }

    func getSignaturesForAddress(address: String, configs: RequestConfiguration?) async throws -> [SignatureInfo] {
        signaturesToReturn
    }

    func getTransaction(signature: String, commitment: Commitment?) async throws -> TransactionInfo? {
        transactionsBySignature[signature]
    }

    func sendTransaction(transaction: String, configs: RequestConfiguration) async throws -> String {
        sendTransactionCallCount += 1
        lastSentTransactionBase64 = transaction
        return transactionIdToReturn
    }
}

