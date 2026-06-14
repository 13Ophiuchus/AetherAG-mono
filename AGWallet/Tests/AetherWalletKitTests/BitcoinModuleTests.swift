import XCTest
@testable import AetherWalletKit

class BitcoinModuleTests: XCTestCase {

    var keyManager: MockKeyManagerActor!
    var bitcoinModule: BitcoinModule!

    override func setUp() {
        super.setUp()
        keyManager = MockKeyManagerActor()
        bitcoinModule = BitcoinModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockBitcoin()

        // When
        let balance = try await bitcoinModule.getBalance(for: asset)

        // Then
        XCTAssertEqual(balance, 1.23)
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockBitcoin()
        let amount = 0.5
        let recipient = "mock_recipient_address"

        // When
        let transaction = try await bitcoinModule.send(amount: amount, to: recipient, for: asset)

        // Then
        XCTAssertNotNil(transaction)
        guard case .bitcoin(let btcTx) = transaction else {
            XCTFail("Incorrect transaction type")
            return
        }
        XCTAssertFalse(btcTx.txId.isEmpty)
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockBitcoinChain()

        // When
        let signature = try await bitcoinModule.signMessage(message, on: chain)

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