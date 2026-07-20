import Foundation
import LocalAuthentication
import AetherSharedProtocols

// MARK: - KeyStorageProviding

// Abstraction over secure key storage so KeyManagerActor can be tested with an
// in-memory fake, while production code continues to use Secure Enclave/Keychain.
public protocol KeyStorageProviding: WalletKeyStoring {
    func storeKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws
    func retrieveKey(for identifier: String) throws -> Data?
    func deleteKey(for identifier: String) throws
}

public extension KeyStorageProviding {
    func storeKey(
        _ key: Data,
        for identifier: String,
        requiresBiometrics: Bool
    ) async throws {
        try _syncStoreKey(key, for: identifier, requiresBiometrics: requiresBiometrics)
    }

    func retrieveKey(for identifier: String) async throws -> Data? {
        try _syncRetrieveKey(for: identifier)
    }

    func deleteKey(for identifier: String) async throws {
        try _syncDeleteKey(for: identifier)
    }
}

private extension KeyStorageProviding {
    func _syncStoreKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws {
        try storeKey(key, for: identifier, requiresBiometrics: requiresBiometrics)
    }

    func _syncRetrieveKey(for identifier: String) throws -> Data? {
        try retrieveKey(for: identifier)
    }

    func _syncDeleteKey(for identifier: String) throws {
        try deleteKey(for: identifier)
    }
}

// MARK: - KeychainKeyStorageProvider

// Production storage provider backed by Secure Enclave (when available) and Keychain.
public final class KeychainKeyStorageProvider: KeyStorageProviding, @unchecked Sendable {
    private let secureEnclaveManager = KeyManagerSecureEnclaveStore()
    private let keychainManager = KeyManagerKeychainStore()

    public init() {}

    public func storeKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws {
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

    public func retrieveKey(for identifier: String) throws -> Data? {
        if secureEnclaveManager.isAvailable, secureEnclaveManager.keyExists(with: identifier) {
            return try secureEnclaveManager.retrieveKey(with: identifier)
        }
        return try keychainManager.retrieve(with: identifier)
    }

    public func deleteKey(for identifier: String) throws {
        if secureEnclaveManager.isAvailable, secureEnclaveManager.keyExists(with: identifier) {
            try secureEnclaveManager.deleteKey(with: identifier)
        }
        try keychainManager.delete(with: identifier)
    }
}

// MARK: - InMemoryKeyStorageProvider

// Test-only storage provider that keeps keys in memory. Never use in production —
// keys are not encrypted or persisted securely, only suitable for unit tests.
public final class InMemoryKeyStorageProvider: KeyStorageProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    public func storeKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[identifier] = key
    }

    public func retrieveKey(for identifier: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[identifier]
    }

    public func deleteKey(for identifier: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: identifier)
    }
}
