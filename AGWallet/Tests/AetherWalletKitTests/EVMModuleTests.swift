import XCTest
@testable import AetherWalletKit

class EVMModuleTests: XCTestCase {

    var keyManager: KeyManagerActor!
    var evmModule: EVMModule!

    override func setUp() {
        super.setUp()
        keyManager = KeyManagerActor()
        evmModule = EVMModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockEthereum()

        // When / Then: without a master key stored, we expect a keychainError("Master key not found").
        do {
            _ = try await evmModule.getBalance(for: asset)
            XCTFail("Expected keychainError(\"Master key not found\") for EVM getBalance")
        } catch WalletError.keychainError(let message) {
            XCTAssertEqual(message, "Master key not found")
        }
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockEthereum()
        let amount = 0.01
        let recipient = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb9"

        // When / Then: without a master key, we expect keychainError("Master key not found").
        do {
            _ = try await evmModule.send(amount: amount, to: recipient, for: asset)
            XCTFail("Expected keychainError(\"Master key not found\") for EVM send")
        } catch WalletError.keychainError(let message) {
            XCTAssertEqual(message, "Master key not found")
        }
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockEthereumChain()

        // When / Then: without a master key, we expect keychainError("Master key not found").
        do {
            _ = try await evmModule.signMessage(message, on: chain)
            XCTFail("Expected keychainError(\"Master key not found\") for EVM signMessage")
        } catch WalletError.keychainError(let message) {
            XCTAssertEqual(message, "Master key not found")
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