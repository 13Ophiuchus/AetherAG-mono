@testable import AetherWalletKit
import Foundation
import Testing

@Suite("ChainConfigurationService", .serialized)
struct ChainConfigurationServiceTests {

    private func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "AetherWalletKit.ChainConfigs",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func makeService(predefined: [ChainConfig] = []) -> ChainConfigurationService {
        clearKeychain()
        return ChainConfigurationService(predefinedChains: predefined)
    }

    @Test("addChain adds a new chain successfully")
    func addChainSucceeds() async throws {
        let service = makeService()
        let chain = ChainConfig.mockEthereumChain()

        try await service.addChain(chain)
        let chains = await service.availableChains

        #expect(chains.contains(where: { $0.chainId == chain.chainId }))
        clearKeychain()
    }

    @Test("addChain throws chainAlreadyExists for duplicate chainId")
    func addChainRejectsDuplicate() async throws {
        let service = makeService()
        let chain = ChainConfig.mockEthereumChain()

        try await service.addChain(chain)

        do {
            try await service.addChain(chain)
            Issue.record("Expected chainAlreadyExists to be thrown")
        } catch let ChainConfigurationError.chainAlreadyExists {
            // expected
        }
        clearKeychain()
    }

    @Test("updateChain updates an existing chain")
    func updateChainSucceeds() async throws {
        let service = makeService()
        let chain = ChainConfig.mockEthereumChain()
        try await service.addChain(chain)

        let updated = ChainConfig(
            chainId: chain.chainId,
            name: "Updated Name",
            type: chain.type,
            activeNetwork: chain.activeNetwork,
            networks: chain.networks,
            derivationPath: chain.derivationPath,
            nativeAssetSymbol: chain.nativeAssetSymbol
        )
        try await service.updateChain(updated)

        let chains = await service.availableChains
        #expect(chains.first(where: { $0.chainId == chain.chainId })?.name == "Updated Name")
        clearKeychain()
    }

    @Test("updateChain throws chainNotFound for unknown chainId")
    func updateChainRejectsUnknown() async throws {
        let service = makeService()
        let chain = ChainConfig.mockEthereumChain()

        do {
            try await service.updateChain(chain)
            Issue.record("Expected chainNotFound to be thrown")
        } catch let ChainConfigurationError.chainNotFound {
            // expected
        }
        clearKeychain()
    }

    @Test("removeChain removes an existing chain")
    func removeChainSucceeds() async throws {
        let service = makeService()
        let chain = ChainConfig.mockEthereumChain()
        try await service.addChain(chain)

        try await service.removeChain(with: chain.chainId)

        let chains = await service.availableChains
        #expect(!chains.contains(where: { $0.chainId == chain.chainId }))
        clearKeychain()
    }

    @Test("removeChain throws chainNotFound for unknown chainId")
    func removeChainRejectsUnknown() async throws {
        let service = makeService()

        do {
            try await service.removeChain(with: "nonexistent-chain-id")
            Issue.record("Expected chainNotFound to be thrown")
        } catch let ChainConfigurationError.chainNotFound {
            // expected
        }
        clearKeychain()
    }

    @Test("getPredefinedChains returns only predefined chains, unaffected by additions")
    func predefinedChainsAreIsolated() async throws {
        let predefined = [ChainConfig.mockSolanaChain()]
        let service = makeService(predefined: predefined)

        try await service.addChain(ChainConfig.mockEthereumChain())

        let predefinedResult = await service.getPredefinedChains()
        #expect(predefinedResult.count == 1)
        #expect(predefinedResult.first?.chainId == predefined.first?.chainId)
        clearKeychain()
    }

    @Test("availableChains persists across service instances via Keychain")
    func persistsAcrossInstances() async throws {
        clearKeychain()
        let service1 = ChainConfigurationService(predefinedChains: [])
        let chain = ChainConfig.mockEthereumChain()
        try await service1.addChain(chain)

        let service2 = ChainConfigurationService(predefinedChains: [])
        try await Task.sleep(nanoseconds: 100_000_000)
        let chains = await service2.availableChains

        #expect(chains.contains(where: { $0.chainId == chain.chainId }))
        clearKeychain()
    }
}
