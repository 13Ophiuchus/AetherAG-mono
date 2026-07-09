import XCTest
@testable import AetherWalletKit

class FlowModuleTests: XCTestCase {

    var keyManager: KeyManagerActor!
    var flowModule: FlowModule!

    override func setUp() {
        super.setUp()
        keyManager = KeyManagerActor()
        flowModule = FlowModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockFlow()

        // When / Then: Flow balance lookup is intentionally unsupported today.
        do {
            _ = try await flowModule.getBalance(for: asset)
            XCTFail("Expected unsupportedOperation for Flow balance lookup")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Flow balance lookup"), "Unexpected message: \(message)")
        }
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockFlow()
        let amount = 10.0
        let recipient = "0x7659f11a8bdf8b31"

        // When / Then: Flow token transfer is intentionally unsupported today.
        do {
            _ = try await flowModule.send(amount: amount, to: recipient, for: asset)
            XCTFail("Expected unsupportedOperation for Flow token transfer")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Flow token transfer"), "Unexpected message: \(message)")
        }
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockFlowChain()

        // When / Then: Flow message signing is intentionally unsupported today.
        do {
            _ = try await flowModule.signMessage(message, on: chain)
            XCTFail("Expected unsupportedOperation for Flow message signing")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Flow message signing"), "Unexpected message: \(message)")
        }
    }
}

// MARK: - Mocks

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