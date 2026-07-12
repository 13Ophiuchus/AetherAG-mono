import Foundation
import Foundation
import Testing
@testable import AetherWalletKit

@Suite("BitcoinModule")
struct BitcoinModuleTests {

    private func makeModule() -> BitcoinModule {
        BitcoinModule(keyManager: KeyManagerActor())
    }

    private func makeModuleWithKey() async throws -> (BitcoinModule, KeyManagerActor) {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)
        return (BitcoinModule(keyManager: keyManager), keyManager)
    }

    @Test("getBalance fails with keychainError when no master key is stored")
    func testGetBalance() async throws {
        let bitcoinModule = makeModule()
        let asset = CryptoAsset.mockBitcoin()

        do {
            _ = try await bitcoinModule.getBalance(for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for Bitcoin getBalance")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

    @Test("send fails with keychainError when no master key is stored")
    func testSendTransaction() async throws {
        let bitcoinModule = makeModule()
        let asset = CryptoAsset.mockBitcoin()
        let amount = 0.5
        let recipient = "mock_recipient_address"

        do {
            _ = try await bitcoinModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for Bitcoin send")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

    @Test("signMessage fails with keychainError when no master key is stored")
    func testSignMessage() async throws {
        let bitcoinModule = makeModule()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockBitcoinChain()

        do {
            _ = try await bitcoinModule.signMessage(message, on: chain)
            Issue.record("Expected keychainError(\"Master key not found\") for Bitcoin signMessage")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

    @Test("bitcoinAddress(for:) returns a non-empty address once a master key is stored")
    func testBitcoinAddressWithKey() async throws {
        let (_, keyManager) = try await makeModuleWithKey()
        let chain = ChainConfig.mockBitcoinChain()

        let address = try await keyManager.bitcoinAddress(for: chain)

        #expect(!address.isEmpty)
    }

    @Test("signBitcoinMessage produces a non-empty deterministic signature for the same key and message")
    func testSignBitcoinMessageWithKey() async throws {
        let (_, keyManager) = try await makeModuleWithKey()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockBitcoinChain()

        let signature1 = try await keyManager.signBitcoinMessage(message, chain: chain)
        let signature2 = try await keyManager.signBitcoinMessage(message, chain: chain)

        #expect(!signature1.isEmpty)
        #expect(signature1 == signature2)
    }

    @Test("signBitcoinMessage produces different signatures for different messages")
    func testSignBitcoinMessageDifferentInputs() async throws {
        let (_, keyManager) = try await makeModuleWithKey()
        let chain = ChainConfig.mockBitcoinChain()

        let signatureA = try await keyManager.signBitcoinMessage("message A", chain: chain)
        let signatureB = try await keyManager.signBitcoinMessage("message B", chain: chain)

        #expect(signatureA != signatureB)
    }

    @Test("send broadcasts a real native BTC transfer using the injected mock Esplora client")
    func testSendTransactionWithMockEsploraClient() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)

        let chain = ChainConfig.mockBitcoinChain()
        let fromAddress = try await keyManager.bitcoinAddress(for: chain)

        // scriptPubKeyHex below is the P2PKH script for fromAddress itself so that
        // BitcoinScript.p2pkhScript(forAddress:) parity can be exercised end-to-end.
        let mockUTXO = UTXO(
            outpoint: "aaaabbbbccccddddeeeeffff00001111222233334444555566667777888899:0",
            valueSatoshis: 100_000,
            scriptPubKeyHex: try BitcoinScript.p2pkhScript(forAddress: fromAddress).toHexString()
        )

        let mockClient = MockEsploraClient(
            utxosToReturn: [mockUTXO],
            txIdToReturn: "deadbeefcafebabe0000000000000000000000000000000000000000000000"
        )

        let bitcoinModule = BitcoinModule(keyManager: keyManager, esploraClientOverride: mockClient)
        let asset = CryptoAsset.mockBitcoin()
        let recipient = fromAddress

        let result = try await bitcoinModule.send(amount: 0.0005, to: recipient, for: asset)

        guard case let .bitcoin(signedTx) = result else {
            Issue.record("Expected .bitcoin(UnifiedTransaction) case")
            return
        }

        #expect(signedTx.txId == "deadbeefcafebabe0000000000000000000000000000000000000000000000")
        #expect(mockClient.getUTXOsCallCount == 1)
        #expect(mockClient.broadcastCallCount == 1)
        #expect(mockClient.lastBroadcastRawTransaction != nil)
        #expect(!(mockClient.lastBroadcastRawTransaction ?? "").isEmpty)
    }
}

// MARK: - Mocks

extension ChainConfig {
    static func mockBitcoinChain() -> ChainConfig {
        return ChainConfig(
            chainId: "bitcoin",
            name: "Bitcoin",
            type: .bitcoin,
            rpcEndpoints: [URL(string: "http://localhost:8332")!],
            derivationPath: "m/44'/0'/0'/0/0",
            nativeAssetSymbol: "BTC"
        )
    }
}

// MARK: - Mock Esplora Client

// Records calls and returns canned responses so send() can be tested
// end-to-end without any network I/O or risk of broadcasting to mainnet.
final class MockEsploraClient: EsploraClient, @unchecked Sendable {
    let utxosToReturn: [UTXO]
    let txIdToReturn: String

    private(set) var getUTXOsCallCount = 0
    private(set) var broadcastCallCount = 0
    private(set) var lastBroadcastRawTransaction: String?

    init(utxosToReturn: [UTXO], txIdToReturn: String) {
        self.utxosToReturn = utxosToReturn
        self.txIdToReturn = txIdToReturn
    }

    func getUTXOs(for address: String) async throws -> [UTXO] {
        getUTXOsCallCount += 1
        return utxosToReturn
    }

    func getTransactionHistory(for address: String) async throws -> [UnifiedTransaction] {
        return []
    }

    func broadcast(rawTransaction: String) async throws -> String {
        broadcastCallCount += 1
        lastBroadcastRawTransaction = rawTransaction
        return txIdToReturn
    }
}
