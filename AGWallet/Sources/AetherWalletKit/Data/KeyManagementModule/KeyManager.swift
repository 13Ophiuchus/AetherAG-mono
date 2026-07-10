import Foundation
import CryptoKit
import LocalAuthentication
import SolanaSwift
import TweetNacl

// MARK: - KeyManagerActor

public actor KeyManagerActor {
    // MARK: - Chain helpers

    // Returns the primary Solana address for the given chain configuration.
    public func solanaAddress(for chain: ChainConfig) async throws -> String {
        let account = try await solanaAccount(for: chain)
        return account.publicKey.base58EncodedString
    }

    // Signs a Solana message for the given chain configuration.
    // Returns the base58-encoded Ed25519 detached signature over the UTF-8 message bytes.
    public func signSolanaMessage(_ message: String, chain: ChainConfig) async throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.signingFailed("Message is not valid UTF-8")
        }
        let account = try await solanaAccount(for: chain)
        let signature = try NaclSign.signDetached(message: messageData, secretKey: account.secretKey)
        return Base58.encode(signature)
    }

    // Signs a Solana transfer transaction for the given chain configuration.
    // NOTE: SolanaTransaction currently carries metadata (blockhash, instructions, fee)
    // rather than a fully serialized wire-format message. This signs a deterministic
    // digest of that metadata as an interim measure; full production support requires
    // serializing the compiled transaction message per the Solana wire format before
    // signing, so the signature covers exactly the bytes broadcast to the cluster.
    public func signSolanaTransfer(_ transaction: SolanaTransaction, chain: ChainConfig) async throws -> String {
        let account = try await solanaAccount(for: chain)

        var digestInput = transaction.recentBlockhash
        for instruction in transaction.instructions {
            digestInput += instruction.programId
            digestInput += instruction.accounts.joined(separator: ",")
            digestInput += instruction.data
        }

        guard let digestData = digestInput.data(using: .utf8) else {
            throw WalletError.signingFailed("Unable to encode transaction digest")
        }

        let hashed = Data(SHA256.hash(data: digestData))
        let signature = try NaclSign.signDetached(message: hashed, secretKey: account.secretKey)
        return Base58.encode(signature)
    }

    // Derives the SolanaSwift Account (Ed25519 keypair) from the stored master key material.
    private func solanaAccount(for chain: ChainConfig) async throws -> Account {
        guard let masterKey = try retrievePrivateKey(for: "masterKey") else {
            throw WalletError.keychainError("Master key not found")
        }
        // Solana Ed25519 keys require a 32-byte seed; NaclSign derives the 64-byte
        // secret key (seed + public key) from it via keyPair(fromSecretKey:).
        let seed = masterKey.count >= 32 ? masterKey.prefix(32) : masterKey
        let keyPair = try NaclSign.KeyPair.keyPair(fromSeed: Data(seed))
        return try Account(secretKey: keyPair.secretKey)
    }

    // Signs a Bitcoin transaction draft for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 transaction signing strategy is finalized.
    func signBitcoinTransaction(_ draft: BitcoinTxDraft, chain: ChainConfig) async throws -> String {
        // TODO: Implement real Bitcoin transaction signing via stored key material.
        throw WalletError.unsupportedOperation("signBitcoinTransaction(_:chain:) not yet implemented")
    }

    // Signs a Bitcoin message for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 signing and message encoding strategy are finalized.
    public func signBitcoinMessage(_ message: String, chain: ChainConfig) async throws -> String {
        // TODO: Implement real Bitcoin message signing via stored key material.
        throw WalletError.unsupportedOperation("signBitcoinMessage(_:chain:) not yet implemented")
    }

    // Returns the primary Bitcoin address for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 key derivation and HD path strategy are finalized.
    public func bitcoinAddress(for chain: ChainConfig) async throws -> String {
        // TODO: Derive Bitcoin address from stored key material for the given chain.
        // For now, this is a placeholder that throws until the derivation is wired.
        throw WalletError.unsupportedOperation("bitcoinAddress(for:) not yet implemented")
    }
    private let secureEnclaveManager = SecureEnclaveManager()
    private let keychainManager = KeychainManager()

    public func generateMnemonic(strength: Int = 128) throws -> [String] {
        return try Mnemonic.generate(strength: strength).words
    }

    public func generateMasterPrivateKey(from mnemonic: [String], passphrase: String = "") throws -> Data {
        let seed = Mnemonic(words: mnemonic).seed(passphrase: passphrase)
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
        // Secure Enclave availability check: requires biometry/device support.
        // SecKeyIsAlgorithmSupported needs an actual SecKey instance to query,
        // so we use LAContext to check hardware capability instead.
        var error: NSError?
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
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
		guard SecKeyCreateWithData(key as CFData, attributes as CFDictionary, &error) != nil else {
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

public enum DerivationPathError: Error, LocalizedError {
    case emptyPath
    case invalidComponent(String)
    case invalidHardenedIndex(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "Derivation path is empty"
        case .invalidComponent(let c):
            return "Invalid derivation path component: \(c)"
        case .invalidHardenedIndex(let c):
            return "Invalid hardened index value: \(c)"
        }
    }
}

// MARK: - DerivationPath

public struct DerivationPath {
    public let indexes: [UInt32]

    public init(_ path: String) throws {
        let stripped = path.hasPrefix("m/") ? String(path.dropFirst(2)) : path
        guard !stripped.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DerivationPathError.emptyPath
        }
        var parsedIndexes = [UInt32]()
        for component in stripped.split(separator: "/") {
            let comp = String(component)
            if comp == "m" { continue }
            if comp.hasSuffix("'") || comp.hasSuffix("h") {
                let numStr = String(comp.dropLast())
                guard let number = UInt32(numStr), number < 0x80000000 else {
                    throw DerivationPathError.invalidHardenedIndex(comp)
                }
                parsedIndexes.append(number | 0x80000000)
            } else {
                guard let value = UInt32(comp) else {
                    throw DerivationPathError.invalidComponent(comp)
                }
                parsedIndexes.append(value)
            }
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
