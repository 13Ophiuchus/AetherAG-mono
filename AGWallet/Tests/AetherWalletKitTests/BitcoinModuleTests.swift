import XCTest
@testable import AetherWalletKit

class BitcoinModuleTests: XCTestCase {

    var keyManager: KeyManagerActor!
    var bitcoinModule: BitcoinModule!

    override func setUp() {
        super.setUp()
        keyManager = KeyManagerActor()
        bitcoinModule = BitcoinModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockBitcoin()

        // When / Then: currently Bitcoin address derivation is not implemented,
        // so we expect an unsupportedOperation error rather than a real balance.
        do {
            _ = try await bitcoinModule.getBalance(for: asset)
            XCTFail("Expected unsupportedOperation for Bitcoin address derivation")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Bitcoin address derivation"), "Unexpected message: \(message)")
        }
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockBitcoin()
        let amount = 0.5
        let recipient = "mock_recipient_address"

        // When / Then: transaction signing is not yet implemented,
        // so we expect an unsupportedOperation error.
        do {
            _ = try await bitcoinModule.send(amount: amount, to: recipient, for: asset)
            XCTFail("Expected unsupportedOperation for Bitcoin transaction signing")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Bitcoin address derivation") || message.contains("transaction signing"))
        }
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockBitcoinChain()

        // When / Then: message signing is not yet implemented,
        // so we expect an unsupportedOperation error.
        do {
            _ = try await bitcoinModule.signMessage(message, on: chain)
            XCTFail("Expected unsupportedOperation for Bitcoin message signing")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Bitcoin message signing"), "Unexpected message: \(message)")
        }
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