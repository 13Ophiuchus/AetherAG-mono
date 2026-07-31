//
//  BitcoinAddressTypeTests.swift
//  AGWallet
//

import Foundation
import Testing
@testable import AetherWalletKit

@Suite("BitcoinAddressType")
struct BitcoinAddressTypeTests {

    private func makeKeyManagerWithMasterKey() async throws -> KeyManagerActor {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)
        return keyManager
    }

    private func testChain(network: ChainNetwork) -> ChainConfig {
        let base = ChainConfig.mockBitcoinChain()
        return base.withActiveNetwork(network)
    }

    @Test("Mainnet P2WPKH address uses bc1q prefix")
    func mainnetPrefix() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let address = try await keyManager.bitcoinAddress(
            for: testChain(network: .mainnet),
            addressType: .p2wpkh
        )
        #expect(address.hasPrefix("bc1q"))
    }

    @Test("Testnet P2WPKH address uses tb1q prefix")
    func testnetPrefix() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let address = try await keyManager.bitcoinAddress(
            for: testChain(network: .testnet),
            addressType: .p2wpkh
        )
        #expect(address.hasPrefix("tb1q"))
    }

    @Test("Signet P2WPKH address also uses tb1q prefix")
    func signetPrefix() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let address = try await keyManager.bitcoinAddress(
            for: testChain(network: .signet),
            addressType: .p2wpkh
        )
        #expect(address.hasPrefix("tb1q"))
    }

    @Test("Regtest P2WPKH address uses bcrt1q prefix")
    func regtestPrefix() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let address = try await keyManager.bitcoinAddress(
            for: testChain(network: .regtest),
            addressType: .p2wpkh
        )
        #expect(address.hasPrefix("bcrt1q"))
    }

    @Test("Legacy bitcoinAddress(for:) remains unaffected and matches the .p2pkh overload")
    func legacyBackwardCompatibility() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .mainnet)
        let legacyAddress = try await keyManager.bitcoinAddress(for: chain)
        let explicitP2PKHAddress = try await keyManager.bitcoinAddress(for: chain, addressType: .p2pkh)
        #expect(legacyAddress == explicitP2PKHAddress)
        #expect(legacyAddress.hasPrefix("1") || legacyAddress.hasPrefix("m") || legacyAddress.hasPrefix("n"))
    }

    @Test("P2TR keypath-spend address uses bc1p prefix on mainnet")
    func p2trMainnetAddress() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .mainnet)
        let address = try await keyManager.bitcoinAddress(for: chain, addressType: .p2tr)
        #expect(address.hasPrefix("bc1p"), "Expected bc1p prefix, got \(address)")
        #expect(address.count >= 62, "P2TR address too short: \(address)")
    }

    @Test("P2TR keypath-spend address uses tb1p prefix on testnet")
    func p2trTestnetAddress() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .testnet)
        let address = try await keyManager.bitcoinAddress(for: chain, addressType: .p2tr)
        #expect(address.hasPrefix("tb1p"), "Expected tb1p prefix, got \(address)")
    }

    @Test("P2TR address is deterministic for the same key")
    func p2trIsDeterministic() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .mainnet)
        let addr1 = try await keyManager.bitcoinAddress(for: chain, addressType: .p2tr)
        let addr2 = try await keyManager.bitcoinAddress(for: chain, addressType: .p2tr)
        #expect(addr1 == addr2)
    }

    @Test("P2WPKH hkdfV1 address uses bc1q prefix on mainnet")
    func p2wpkhHkdfV1MainnetAddress() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .mainnet)
        let address = try await keyManager.bitcoinAddress(
            for: chain, addressType: .p2wpkh, derivationVersion: .hkdfV1)
        #expect(address.hasPrefix("bc1q"), "Expected bc1q prefix, got \(address)")
    }

    @Test("P2WPKH hkdfV1 address differs from legacy address")
    func p2wpkhHkdfV1DiffersFromLegacy() async throws {
        let keyManager = try await makeKeyManagerWithMasterKey()
        let chain = testChain(network: .mainnet)
        let legacyAddr = try await keyManager.bitcoinAddress(
            for: chain, addressType: .p2wpkh, derivationVersion: .legacy)
        let hkdfAddr = try await keyManager.bitcoinAddress(
            for: chain, addressType: .p2wpkh, derivationVersion: .hkdfV1)
        #expect(legacyAddr != hkdfAddr)
    }
}

