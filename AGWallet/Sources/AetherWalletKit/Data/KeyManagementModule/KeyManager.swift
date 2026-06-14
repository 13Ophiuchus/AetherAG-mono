import Foundation
import CryptoKit
import LocalAuthentication

// MARK: - KeyManagerActor

public actor KeyManagerActor {
    private let secureEnclaveManager = SecureEnclaveManager()
    private let keychainManager = KeychainManager()

    public func generateMnemonic(strength: MnemonicStrength = .default) throws -> [String] {
        return try Mnemonic.generate(strength: strength)
    }

    public func generateMasterPrivateKey(from mnemonic: [String], passphrase: String = "") throws -> Data {
        let seed = try Mnemonic.deterministicSeed(mnemonic: mnemonic, passphrase: passphrase)
        let hmac = HMAC<SHA512>.authenticationCode(for: seed, using: SymmetricKey(data: "Bitcoin seed".data(using: .utf8)!))
        return Data(hmac)
    }

    public func derivePrivateKey(masterKey: Data, path: String) throws -> Data {
        let derivationPath = try DerivationPath(path)
        var currentKey = masterKey
        
        for index in derivationPath.indexes {
            let hmac = HMAC<SHA512>.authenticationCode(for: currentKey, using: SymmetricKey(data: index.data))
            currentKey = Data(hmac)
        }
        
        return currentKey
    }

    public func storePrivateKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws {
        if secureEnclaveManager.isAvailable, requiresBiometrics {
            try secureEnclaveManager.storeKey(key, with: identifier)
        } else {
            let context = LAContext()
            var error: NSError?
            
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    .userPresence,
                    nil
                )!
                try keychainManager.store(key, with: identifier, accessControl: accessControl)
            } else {
                try keychainManager.store(key, with: identifier)
            }
        }
    }

    public func retrievePrivateKey(for identifier: String) throws -> Data? {
        if secureEnclaveManager.isAvailable, secureEnclaveManager.keyExists(with: identifier) {
            return try secureEnclaveManager.retrieveKey(with: identifier)
        }
        return try keychainManager.retrieve(with: identifier)
    }

    public func deletePrivateKey(for identifier: String) throws {
        if secureEnclaveManager.isAvailable, secureEnclaveManager.keyExists(with: identifier) {
            try secureEnclaveManager.deleteKey(with: identifier)
        }
        try keychainManager.delete(with: identifier)
    }

    public func sign(data: Data, withKeyIdentifier identifier: String) throws -> Data {
        guard let privateKey = try retrievePrivateKey(for: identifier) else {
            throw WalletError.keychainError("Private key not found")
        }
        
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        return try signingKey.signature(for: data).rawRepresentation
    }
}

// MARK: - SecureEnclaveManager

private class SecureEnclaveManager {
    var isAvailable: Bool {
        return SecKeyIsAlgorithmSupported(.ecdsaSignatureMessageX962SHA256, .sign)
    }

    func storeKey(_ key: Data, with identifier: String) throws {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: identifier.data(using: .utf8)!,
                kSecAttrAccessControl as String: createAccessControl()
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(key as CFData, attributes as CFDictionary, &error) else {
            throw WalletError.secureEnclaveError(error.debugDescription)
        }
    }

    func retrieveKey(with identifier: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw WalletError.secureEnclaveError("Failed to retrieve key: \(status)")
        }
        
        return item as? Data
    }

    func keyExists(with identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func deleteKey(with identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier.data(using: .utf8)!
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.secureEnclaveError("Failed to delete key: \(status)")
        }
    }

    private func createAccessControl() -> SecAccessControl {
        return SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        )!
    }
}

// MARK: - KeychainManager

private class KeychainManager {
    func store(_ data: Data, with identifier: String, accessControl: SecAccessControl? = nil) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data
        ]
        
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        }
        
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

    func delete(with identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keychainError("Failed to delete item: \(status)")
        }
    }
}

// MARK: - Mnemonic

public enum MnemonicStrength: Int {
    case `default` = 128
    case low = 128
    case medium = 192
    case high = 256
}

public class Mnemonic {
    public static func generate(strength: MnemonicStrength) throws -> [String] {
        // In a real implementation, this would use a wordlist and proper entropy generation
        let words = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
        return Array(words.shuffled().prefix(12))
    }

    public static func deterministicSeed(mnemonic: [String], passphrase: String) throws -> Data {
        let password = mnemonic.joined(separator: " ").data(using: .utf8)!
        let salt = ("mnemonic" + passphrase).data(using: .utf8)!
        
        // Using PBKDF2 for seed generation
        var derivedKey = Data(count: 64)
        _ = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        2048,
                        derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        64
                    )
                }
            }
        }
        return derivedKey
    }
}

// MARK: - DerivationPath

public struct DerivationPath {
    public let indexes: [UInt32]

    public init(_ path: String) throws {
        let components = path.split(separator: "/")
        var parsedIndexes = [UInt32]()

        for component in components {
            if component == "m" { continue }
            
            var value: UInt32
            if component.hasSuffix("'") {
                let number = String(component.dropLast())
                value = (UInt32(number) ?? 0) | 0x80000000
            } else {
                value = UInt32(component) ?? 0
            }
            parsedIndexes.append(value)
        }
        self.indexes = parsedIndexes
    }
}

extension UInt32 {
    var data: Data {
        var int = self.bigEndian
        return Data(bytes: &int, count: MemoryLayout<UInt32>.size)
    }
}
