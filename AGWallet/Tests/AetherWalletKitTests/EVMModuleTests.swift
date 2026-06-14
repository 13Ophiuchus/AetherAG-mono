import XCTest
@testable import AetherWalletKit

class EVMModuleTests: XCTestCase {

    var keyManager: MockKeyManagerActor!
    var evmModule: EVMModule!

    override func setUp() {
        super.setUp()
        keyManager = MockKeyManagerActor()
        evmModule = EVMModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // This test will fail without a running node or mock RPC responses.
        // For now, it serves as a structural placeholder.
        // Given
        let asset = CryptoAsset.mockEthereum()

        // When
        let balance = try await evmModule.getBalance(for: asset)

        // Then
        XCTAssert(balance >= 0)
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockEthereum()
        let amount = 0.01
        let recipient = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb9"

        // When
        let transaction = try await evmModule.send(amount: amount, to: recipient, for: asset)

        // Then
        XCTAssertNotNil(transaction)
        guard case .evm(let evmTx) = transaction else {
            XCTFail("Incorrect transaction type")
            return
        }
        XCTAssertFalse(evmTx.hash.isEmpty)
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockEthereumChain()

        // When
        let signature = try await evmModule.signMessage(message, on: chain)

        // Then
        XCTAssertFalse(signature.isEmpty)
    }
}

// MARK: - Mocks

class MockKeyManagerActor: KeyManagerActor {
    override func retrievePrivateKey(for identifier: String) throws -> Data? {
        // Return a mock private key for testing
        return Data(repeating: 0, count: 32)
    }
}

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