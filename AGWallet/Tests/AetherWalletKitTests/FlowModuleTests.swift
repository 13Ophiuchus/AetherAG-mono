import XCTest
@testable import AetherWalletKit

class FlowModuleTests: XCTestCase {

    var keyManager: MockKeyManagerActor!
    var flowModule: FlowModule!

    override func setUp() {
        super.setUp()
        keyManager = MockKeyManagerActor()
        flowModule = FlowModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // This test will fail without a running node or mock RPC responses.
        // For now, it serves as a structural placeholder.
        // Given
        let asset = CryptoAsset.mockFlow()

        // When
        let balance = try await flowModule.getBalance(for: asset)

        // Then
        XCTAssert(balance >= 0)
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockFlow()
        let amount = 10.0
        let recipient = "0x7659f11a8bdf8b31"

        // When
        let transaction = try await flowModule.send(amount: amount, to: recipient, for: asset)

        // Then
        XCTAssertNotNil(transaction)
        guard case .flow(let flowTx) = transaction else {
            XCTFail("Incorrect transaction type")
            return
        }
        XCTAssertFalse(flowTx.id.isEmpty)
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockFlowChain()

        // When
        let signature = try await flowModule.signMessage(message, on: chain)

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
    static func mockFlowChain() -> ChainConfig {
        return ChainConfig(
            chainId: "flow-mainnet",
            name: "Flow",
            type: .flow,
            rpcEndpoints: [URL(string: "https://rest-mainnet.onflow.org/v1")!],
            derivationPath: "m/44'/539'/0'/0/0",
            nativeAssetSymbol: "FLOW"
        )
    }
}