import XCTest
@testable import AetherWalletKit

class SolanaModuleTests: XCTestCase {

    var keyManager: KeyManagerActor!
    var solanaModule: SolanaModule!

    override func setUp() {
        super.setUp()
        keyManager = KeyManagerActor()
        solanaModule = SolanaModule(keyManager: keyManager)
    }

    func testGetBalance() async throws {
        // Given
        let asset = CryptoAsset.mockSolana()

        // When / Then: without a master key stored, we expect keychainError("Master key not found").
        do {
            _ = try await solanaModule.getBalance(for: asset)
            XCTFail("Expected keychainError(\"Master key not found\") for Solana getBalance")
        } catch WalletError.keychainError(let message) {
            XCTAssertEqual(message, "Master key not found")
        }
    }

    func testSendTransaction() async throws {
        // Given
        let asset = CryptoAsset.mockSolana()
        let amount = 1.5
        let recipient = "So11111111111111111111111111111111111111112"

        // When / Then: native SOL send is not yet implemented,
        // so we expect an unsupportedOperation error.
        do {
            _ = try await solanaModule.send(amount: amount, to: recipient, for: asset)
            XCTFail("Expected unsupportedOperation for native SOL send")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Native SOL send"), "Unexpected message: \(message)")
        }
    }

    func testSignMessage() async throws {
        // Given
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockSolanaChain()

        // When / Then: Solana message signing is not yet implemented.
        do {
            _ = try await solanaModule.signMessage(message, on: chain)
            XCTFail("Expected unsupportedOperation for Solana message signing")
        } catch WalletError.unsupportedOperation(let message) {
            XCTAssertTrue(message.contains("Solana message signing"), "Unexpected message: \(message)")
        }
    }
}

// MARK: - Mocks

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