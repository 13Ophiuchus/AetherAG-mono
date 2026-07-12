import Foundation
import Foundation
import Testing
@testable import AetherWalletKit

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
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }

    @Test("send fails with keychainError when no master key is stored")
    func testSendTransaction() async throws {
        let evmModule = makeModule()
        let asset = CryptoAsset.mockEthereum()
        let amount = 0.01
        let recipient = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb9"

        do {
            _ = try await evmModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM send")
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
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
        } catch WalletError.keychainError(let message) {
            #expect(message == "Master key not found")
        }
    }
}

// MARK: - Mocks

extension ChainConfig {
    static func mockEthereumChain() -> ChainConfig {
        return ChainConfig(
            chainId: "1",
            name: "Ethereum",
            type: .evm,
            rpcEndpoints: [URL(string: "https://mainnet.infura.io/v3/YOUR_PROJECT_ID")!],
            derivationPath: "m/44'/60'/0'/0/0",
            nativeAssetSymbol: "ETH"
        )
    }
}
