//
//  WalletCoreReceiveAddressTests.swift
//  AGWallet
//

import Testing
import Foundation
@testable import AetherWalletKit

// MARK: - ChainConfig test helpers (EVM/Bitcoin/Solana/Flow)

extension ChainConfig {
    static func mockEVM() -> ChainConfig {
        ChainConfig(
            chainId: "1", name: "Ethereum", type: .evm,
            rpcEndpoints: [URL(string: "https://mainnet.infura.io/v3/test")!],
            derivationPath: "m/44'/60'/0'/0/0", nativeAssetSymbol: "ETH"
        )
    }
    static func mockBitcoin() -> ChainConfig {
        ChainConfig(
            chainId: "bitcoin", name: "Bitcoin", type: .bitcoin,
            rpcEndpoints: [URL(string: "http://localhost:8332")!],
            derivationPath: "m/44'/0'/0'/0/0", nativeAssetSymbol: "BTC"
        )
    }
    static func mockSolana() -> ChainConfig {
        ChainConfig(
            chainId: "solana", name: "Solana", type: .solana,
            rpcEndpoints: [URL(string: "https://api.mainnet-beta.solana.com")!],
            derivationPath: "m/44'/501'/0'/0'", nativeAssetSymbol: "SOL"
        )
    }
    static func mockFlow() -> ChainConfig {
        ChainConfig(
            chainId: "flow-mainnet", name: "Flow", type: .flow,
            rpcEndpoints: [URL(string: "https://rest-mainnet.onflow.org/v1")!],
            derivationPath: "m/44'/539'/0'/0/0", nativeAssetSymbol: "FLOW"
        )
    }
}

// MARK: - EVMModule.getReceiveAddress

@Suite("EVMModule.getReceiveAddress")
struct EVMModuleReceiveAddressTests {

    @Test("returns keychainError when no master key is stored")
    func noKeyReturnsKeychainError() async throws {
        let module = EVMModule(keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()))
        do {
            _ = try await module.getReceiveAddress(for: .mockEVM())
            Issue.record("Expected keychainError when no master key is stored")
        } catch WalletError.keychainError { /* expected */ }
    }

    @Test("returns non-empty 0x-prefixed 42-char address when master key is stored")
    func returnsAddressWithMasterKey() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockEVM()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let address = try await EVMModule(keyManager: keyManager).getReceiveAddress(for: chain)
        #expect(address.hasPrefix("0x"))
        #expect(address.count == 42)
    }

    @Test("address is deterministic for the same stored key")
    func addressIsDeterministic() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockEVM()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let module = EVMModule(keyManager: keyManager)
        let a1 = try await module.getReceiveAddress(for: chain)
        let a2 = try await module.getReceiveAddress(for: chain)
        #expect(a1 == a2)
    }
}

// MARK: - FlowModule.getReceiveAddress

@Suite("FlowModule.getReceiveAddress")
struct FlowModuleReceiveAddressTests {

    @Test("returns keychainError when no Flow address is stored")
    func noAddressReturnsKeychainError() async throws {
        let module = FlowModule(keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()))
        do {
            _ = try await module.getReceiveAddress(for: .mockFlow())
            Issue.record("Expected keychainError")
        } catch WalletError.keychainError { /* expected */ }
    }

    @Test("returns 0x-prefixed address after storeFlowAddress")
    func returnsStoredFlowAddress() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let testAddress = "7659f11a8bdf8b31"
        try await keyManager.storeFlowAddress(testAddress)   // sync — not async

        let address = try await FlowModule(keyManager: keyManager).getReceiveAddress(for: .mockFlow())
        #expect(address.hasPrefix("0x"))
        #expect(address.lowercased().contains(testAddress.lowercased()))
    }
}

// MARK: - BitcoinModule.getReceiveAddress

@Suite("BitcoinModule.getReceiveAddress")
struct BitcoinModuleReceiveAddressTests {

    @Test("returns keychainError when no master key is stored")
    func noKeyReturnsKeychainError() async throws {
        let module = BitcoinModule(keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()))
        do {
            _ = try await module.getReceiveAddress(for: .mockBitcoin())
            Issue.record("Expected keychainError when no master key is stored")
        } catch WalletError.keychainError { /* expected */ }
    }

    @Test("returns non-empty address when master key is stored")
    func returnsAddressWithMasterKey() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockBitcoin()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: "masterKey", requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: "masterKey") } }

        let address = try await BitcoinModule(keyManager: keyManager).getReceiveAddress(for: chain)
        #expect(!address.isEmpty)
        #expect(address.count >= 26)
    }

    @Test("address is deterministic for the same stored key")
    func addressIsDeterministic() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockBitcoin()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: "masterKey", requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: "masterKey") } }

        let module = BitcoinModule(keyManager: keyManager)
        let a1 = try await module.getReceiveAddress(for: chain)
        let a2 = try await module.getReceiveAddress(for: chain)
        #expect(a1 == a2)
    }

    @Test("mainnet and testnet addresses differ for the same master key (version byte)")
    func mainnetAndTestnetAddressesDiffer() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mainnetChain = ChainConfig.mockBitcoin()
        let testnetChain = ChainConfig(
            chainId: "bitcoin-testnet", name: "Bitcoin Testnet", type: .bitcoin,
            rpcEndpoints: [URL(string: "http://localhost:18332")!],
            derivationPath: "m/44'/1'/0'/0/0", nativeAssetSymbol: "BTC",
            network: .testnet
        )
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: "masterKey", requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: "masterKey") } }

        let module = BitcoinModule(keyManager: keyManager)
        let mainnetAddress = try await module.getReceiveAddress(for: mainnetChain)
        let testnetAddress = try await module.getReceiveAddress(for: testnetChain)
        #expect(mainnetAddress != testnetAddress)
    }
}

// MARK: - SolanaModule.getReceiveAddress

@Suite("SolanaModule.getReceiveAddress")
struct SolanaModuleReceiveAddressTests {

    @Test("returns keychainError when no master key is stored")
    func noKeyReturnsKeychainError() async throws {
        let module = SolanaModule(keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()))
        do {
            _ = try await module.getReceiveAddress(for: .mockSolana())
            Issue.record("Expected keychainError when no master key is stored")
        } catch WalletError.keychainError { /* expected */ }
    }

    @Test("returns non-empty base58 address when master key is stored")
    func returnsAddressWithMasterKey() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockSolana()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let address = try await SolanaModule(keyManager: keyManager).getReceiveAddress(for: chain)
        #expect(!address.isEmpty)
        #expect(!address.contains("0") && !address.contains("O") && !address.contains("I") && !address.contains("l"))
    }

    @Test("address is deterministic for the same stored key")
    func addressIsDeterministic() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockSolana()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let module = SolanaModule(keyManager: keyManager)
        let a1 = try await module.getReceiveAddress(for: chain)
        let a2 = try await module.getReceiveAddress(for: chain)
        #expect(a1 == a2)
    }

    @Test("works with nil rpcClientOverride without requiring live network")
    func worksWithoutLiveNetwork() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockSolana()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let module = SolanaModule(keyManager: keyManager, rpcClientOverride: nil)
        let address = try await module.getReceiveAddress(for: chain)
        #expect(!address.isEmpty)
    }
}

// MARK: - WalletCore.getReceiveAddress dispatch

@Suite("WalletCore.getReceiveAddress")
struct WalletCoreReceiveAddressTests {

    private func allDisabled() -> WalletCore {
        WalletCore(
            keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()),
            chainConfigService: ChainConfigurationService(),
            enableBitcoin: false, enableSolana: false, enableEVM: false, enableFlow: false
        )
    }

    @Test("throws unsupportedOperation for EVM when module disabled")
    func evmDisabledThrows() async throws {
        do {
            _ = try await allDisabled().getReceiveAddress(for: .mockEVM())
            Issue.record("Expected unsupportedOperation")
        } catch WalletError.unsupportedOperation(let msg) {
            #expect(msg.contains("EVM"))
        }
    }

    @Test("throws unsupportedOperation for Bitcoin when module disabled")
    func bitcoinDisabledThrows() async throws {
        do {
            _ = try await allDisabled().getReceiveAddress(for: .mockBitcoin())
            Issue.record("Expected unsupportedOperation")
        } catch WalletError.unsupportedOperation(let msg) {
            #expect(msg.contains("Bitcoin"))
        }
    }

    @Test("throws unsupportedOperation for Solana when module disabled")
    func solanaDisabledThrows() async throws {
        do {
            _ = try await allDisabled().getReceiveAddress(for: .mockSolana())
            Issue.record("Expected unsupportedOperation")
        } catch WalletError.unsupportedOperation(let msg) {
            #expect(msg.contains("Solana"))
        }
    }

    @Test("throws unsupportedOperation for Flow when module disabled")
    func flowDisabledThrows() async throws {
        do {
            _ = try await allDisabled().getReceiveAddress(for: .mockFlow())
            Issue.record("Expected unsupportedOperation")
        } catch WalletError.unsupportedOperation(let msg) {
            #expect(msg.contains("Flow"))
        }
    }

    @Test("EVM enabled — delegates to EVMModule, returns 0x address")
    func evmEnabledDelegates() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let chain = ChainConfig.mockEVM()
        let mnemonic = try await keyManager.generateMnemonic()
        let masterKey = try await keyManager.generateMasterPrivateKey(from: mnemonic)
        try await keyManager.storePrivateKey(Data(masterKey.prefix(32)), for: chain.chainId, requiresBiometrics: false)
        defer { Task { try? await keyManager.deletePrivateKey(for: chain.chainId) } }

        let core = WalletCore(
            keyManager: keyManager, chainConfigService: ChainConfigurationService(),
            enableBitcoin: false, enableSolana: false, enableEVM: true, enableFlow: false
        )
        let address = try await core.getReceiveAddress(for: chain)
        #expect(address.hasPrefix("0x"))
        #expect(address.count == 42)
    }

    @Test("Flow enabled — delegates to FlowModule, returns stored address")
    func flowEnabledDelegates() async throws {
        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        try await keyManager.storeFlowAddress("7659f11a8bdf8b31")   // sync

        let core = WalletCore(
            keyManager: keyManager, chainConfigService: ChainConfigurationService(),
            enableBitcoin: false, enableSolana: false, enableEVM: false, enableFlow: true
        )
        let address = try await core.getReceiveAddress(for: .mockFlow())
        #expect(address.hasPrefix("0x"))
        #expect(address.lowercased().contains("7659f11a8bdf8b31"))
    }
}
