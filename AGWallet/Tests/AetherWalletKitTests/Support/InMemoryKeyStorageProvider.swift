import Foundation
@testable import AetherWalletKit

// In-memory KeyStorageProviding used in tests so that signing/storage tests
// don't depend on the real Keychain, which requires code-signing entitlements
// unavailable to unsigned `swift test` binaries (fails with errSecMissingEntitlement / -34018).
final class InMemoryKeyStorageProvider: KeyStorageProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func storeKey(_ key: Data, for identifier: String, requiresBiometrics: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[identifier] = key
    }

    func retrieveKey(for identifier: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[identifier]
    }

    func deleteKey(for identifier: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: identifier)
    }
}
