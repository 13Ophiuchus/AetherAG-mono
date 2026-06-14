import XCTest
@testable import AetherWalletKit

class SolanaModuleTests: XCTestCase {

    var keyManager: MockKeyManagerActor!
    var solanaModule: SolanaModule!

    override func setUp() {
        super.setUp()
        keyManager = MockKeyManagerActor()
        solanaModule = SolanaModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockSolana()

        // When
        let balance = try await solanaModule.getBalance(for: asset)

        // Then
        XCTAssertEqual(balance, 5.67)
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockSolana()
        let amount = 1.5
        let recipient = "So11111111111111111111111111111111111111112"

        // When
        let transaction = try await solanaModule.send(amount: amount, to: recipient, for: asset)

        // Then
        XCTAssertNotNil(transaction)
        guard case .solana(let solTx) = transaction else {
            XCTFail("Incorrect transaction type")
            return
        }
        XCTAssertFalse(solTx.signature.isEmpty)
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockSolanaChain()

        // When
        let signature = try await solanaModule.signMessage(message, on: chain)

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