import Testing
import Foundation
@testable import AetherWalletKit

@Suite("KeyManagerActor derivation isolation")
struct KeyManagerActorDerivationIsolationTests {

    private func bitcoinTestChain() -> ChainConfig {
        ChainConfig(
            chainId: "bitcoin",
            name: "Bitcoin",
            type: .bitcoin,
            rpcEndpoints: [URL(string: "https://blockstream.info/api")!],
            derivationPath: "m/44'/0'/0'/0/0",
            nativeAssetSymbol: "BTC"
        )
    }

    private func solanaTestChain(name: String = "Solana") -> ChainConfig {
        ChainConfig(
            chainId: "solana",
            name: name,
            type: .solana,
            rpcEndpoints: [URL(string: "https://api.mainnet-beta.solana.com")!],
            derivationPath: "m/44'/501'/0'/0'",
            nativeAssetSymbol: "SOL"
        )
    }

    private func makeManagerWithMasterKey() async throws -> KeyManagerActor {
        let manager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mnemonic = try await manager.generateMnemonic()
        let masterKey = try await manager.generateMasterPrivateKey(from: mnemonic)
        try await manager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)
        return manager
    }

    @Test("hkdfV1 Bitcoin and Solana derived secrets differ for same master key")
    func crossChainDerivationDiffers() async throws {
        let keyManager = try await makeManagerWithMasterKey()
        let btcChain = bitcoinTestChain()
        let solChain = solanaTestChain()

        let btcAddress = try await keyManager.bitcoinAddress(
            for: btcChain, addressType: .p2wpkh, derivationVersion: .hkdfV1
        )
        let solAddress = try await keyManager.solanaAddress(
            for: solChain, derivationVersion: .hkdfV1
        )

        #expect(btcAddress != solAddress)
    }

    @Test("legacy derivation is stable across repeated calls")
    func legacyDerivationDeterministic() async throws {
        let keyManager = try await makeManagerWithMasterKey()
        let chain = bitcoinTestChain()
        let addr1 = try await keyManager.bitcoinAddress(for: chain)
        let addr2 = try await keyManager.bitcoinAddress(for: chain)
        #expect(addr1 == addr2)
    }

    @Test("empty chain name is rejected by validateSigningIntent")
    func emptyChainNameRejected() async throws {
        let keyManager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain(name: "")
        await #expect(throws: WalletError.self) {
            _ = try await keyManager.signSolanaMessage("test", chain: chain)
        }
    }
}
