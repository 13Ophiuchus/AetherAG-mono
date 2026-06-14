import Foundation
import Combine

public actor ChainConfigurationService {
    private let keychainManager = KeychainManager()
    private let predefinedChains: [ChainConfig]
    
    @Published public private(set) var availableChains: [ChainConfig] = []
    
    public init(predefinedChains: [ChainConfig] = []) {
        self.predefinedChains = predefinedChains
        self.availableChains = loadChains()
    }
    
    public func addChain(_ chain: ChainConfig) throws {
        guard !availableChains.contains(where: { $0.chainId == chain.chainId }) else {
            throw ChainConfigurationError.chainAlreadyExists
        }
        
        availableChains.append(chain)
        try saveChains()
    }
    
    public func updateChain(_ chain: ChainConfig) throws {
        guard let index = availableChains.firstIndex(where: { $0.chainId == chain.chainId }) else {
            throw ChainConfigurationError.chainNotFound
        }
        
        availableChains[index] = chain
        try saveChains()
    }
    
    public func removeChain(with chainId: String) throws {
        guard let index = availableChains.firstIndex(where: { $0.chainId == chainId }) else {
            throw ChainConfigurationError.chainNotFound
        }
        
        availableChains.remove(at: index)
        try saveChains()
    }
    
    public func getPredefinedChains() -> [ChainConfig] {
        return predefinedChains
    }
    
    private func loadChains() -> [ChainConfig] {
        do {
            guard let data = try keychainManager.retrieve(with: "AetherWalletKit.ChainConfigs") else {
                return predefinedChains
            }
            
            let chains = try JSONDecoder().decode([ChainConfig].self, from: data)
            return chains.isEmpty ? predefinedChains : chains
        } catch {
            return predefinedChains
        }
    }
    
    private func saveChains() throws {
        let data = try JSONEncoder().encode(availableChains)
        try keychainManager.store(data, with: "AetherWalletKit.ChainConfigs")
    }
}

public enum ChainConfigurationError: Error, LocalizedError {
    case chainAlreadyExists
    case chainNotFound
    
    public var errorDescription: String? {
        switch self {
        case .chainAlreadyExists:
            return "A chain with this ID already exists."
        case .chainNotFound:
            return "The specified chain could not be found."
        }
    }
}

private class KeychainManager {
    func store(_ data: Data, with identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainError("Failed to store item: \(status)")
        }
    }

    func retrieve(with identifier: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keychainError("Failed to retrieve item: \(status)")
        }
        
        return item as? Data
    }
}