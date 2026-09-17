@testable import AetherWalletKit
import Foundation
import Testing

@Suite("EVMModule")
struct EVMModuleTests {
    private func makeModule() -> EVMModule {
        EVMModule(keyManager: KeyManagerActor())
    }

    @Test("getBalance fails with keychainError when no master key is stored")
    func testGetBalance() async throws {
        let evmModule = makeModule()
        let asset = CryptoAsset.mockEthereum()

        do {
            _ = try await evmModule.getBalance(for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM getBalance")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("send fails with keychainError when no master key is stored")
    func sendTransaction() async throws {
        let evmModule = makeModule()
        let asset = CryptoAsset.mockEthereum()
        let amount = 0.01
        let recipient = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb9"

        do {
            _ = try await evmModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM send")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("signMessage fails with keychainError when no master key is stored")
    func testSignMessage() async throws {
        let evmModule = makeModule()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockEthereumChain()

        do {
            _ = try await evmModule.signMessage(message, on: chain)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM signMessage")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("getTransactionHistory returns empty array when no indexer endpoint is configured")
    func testGetTransactionHistoryNoIndexer() async throws {
        let evmModule = makeModule()
        // mockEthereumChain() has no .indexer role endpoint configured --
        // confirms the non-breaking fallback path added alongside the real
        // EVMIndexerClient-backed implementation.
        let chain = ChainConfig.mockEthereumChain()

        let history = try await evmModule.getTransactionHistory(for: chain)
        #expect(history.isEmpty)
    }
}
