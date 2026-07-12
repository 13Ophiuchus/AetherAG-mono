import Foundation
import Foundation
import Testing
@testable import AetherWalletKit

@Suite("FlowModule")
struct FlowModuleTests {

    private func makeModule() -> FlowModule {
        FlowModule(keyManager: KeyManagerActor())
    }

    @Test("send fails with unsupportedOperation before Flow token transfer is implemented")
    func testSendTransaction() async throws {
        let flowModule = makeModule()
        let asset = CryptoAsset.mockFlow()
        let amount = 10.0
        let recipient = "0x7659f11a8bdf8b31"

        do {
            _ = try await flowModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected unsupportedOperation for Flow token transfer")
        } catch WalletError.unsupportedOperation(let message) {
            #expect(message.contains("Flow token transfer"))
        }
    }

    @Test("signMessage fails with keychainError when no master key is stored")
    func testSignMessageNoKey() async throws {
        let flowModule = makeModule()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockFlowChain()

        do {
            _ = try await flowModule.signMessage(message, on: chain)
            Issue.record("Expected keychainError when no master key is stored")
        } catch WalletError.keychainError {
            // expected
        }
    }

    @Test("signFlowMessage produces valid non-empty signatures (ECDSA_P256 is non-deterministic by design)")
    func testSignFlowMessageDeterministic() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let keyIdentifier = "masterKey-flowTest-\(UUID().uuidString)"
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(masterKey, for: keyIdentifier, requiresBiometrics: false)

        let chain = ChainConfig.mockFlowChain()
        let message = "AetherWalletKit test message"

        do {
            let signature1 = try await keyManager.signFlowMessage(message, chain: chain, keyIdentifier: keyIdentifier)
            let signature2 = try await keyManager.signFlowMessage(message, chain: chain, keyIdentifier: keyIdentifier)

            // ECDSA_P256 signing uses a random nonce per FIPS 186-4, so signature1 and
            // signature2 are expected to differ even for the same key and message.
            // Determinism is verified at the key-derivation level, not the signature level.
            #expect(!signature1.isEmpty)
            #expect(!signature2.isEmpty)
            #expect(signature1 != signature2)
        } catch {
            try? await keyManager.deletePrivateKey(for: keyIdentifier)
            throw error
        }

        try await keyManager.deletePrivateKey(for: keyIdentifier)
    }

    @Test("getBalance fails with keychainError when no Flow address is stored")
    func testGetBalanceNoAddress() async throws {
        let flowModule = makeModule()
        let asset = CryptoAsset.mockFlow()

        do {
            _ = try await flowModule.getBalance(for: asset)
            Issue.record("Expected keychainError when no Flow address is stored")
        } catch WalletError.keychainError {
            // expected
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
