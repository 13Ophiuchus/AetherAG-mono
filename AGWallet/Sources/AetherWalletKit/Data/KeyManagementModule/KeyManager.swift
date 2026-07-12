import Foundation
import CryptoKit
import LocalAuthentication
import SolanaSwift
import TweetNacl
import web3swift
import Web3Core

// MARK: - KeyManagerActor

public actor KeyManagerActor {
    private let storageProvider: KeyStorageProviding

    private enum ChainSigningFamily: String {
        case solanaEd25519 = "solana-ed25519"
        case bitcoinSecp256k1 = "bitcoin-secp256k1"
        case evmSecp256k1 = "evm-secp256k1"
    }

    private enum SigningIntent: String {
        case addressDerivation = "address-derivation"
        case messageSigning = "message-signing"
        case nativeTransfer = "native-transfer"
        case tokenTransfer = "token-transfer"
    }

    public struct SolanaSignedPayload: Sendable {
        public let signature: String
        public let serializedTransactionBase64: String

        public init(signature: String, serializedTransactionBase64: String) {
            self.signature = signature
            self.serializedTransactionBase64 = serializedTransactionBase64
        }
    }

    // Derivation versioning lets existing wallets keep their original addresses
    // (legacy) while new chain integrations can opt into HKDF-derived,
    // chain-and-intent-scoped signing keys (hkdfV1) without breaking anyone
    // already holding funds at a legacy-derived address.
    public enum KeyDerivationVersion: String, Sendable {
        case legacy
        case hkdfV1
    }

    // Default stays legacy so no existing address silently changes.
    // Callers that want the hardened per-chain/per-intent derivation must
    // opt in explicitly via the `derivationVersion` parameter on signing calls.
    // Must be public: Swift requires default-argument values to be at least
    // as visible as the function that uses them.
    public static let defaultDerivationVersion: KeyDerivationVersion = .legacy

    public init(storageProvider: KeyStorageProviding = KeychainKeyStorageProvider()) {
        self.storageProvider = storageProvider
    }

    // MARK: - Chain helpers

    // Returns the primary Solana address for the given chain configuration.
    public func solanaAddress(
        for chain: ChainConfig,
        derivationVersion: KeyDerivationVersion = KeyManagerActor.defaultDerivationVersion
    ) async throws -> String {
        try validateSigningIntent(.addressDerivation, chain: chain)
        let account = try await solanaAccount(for: chain, intent: .addressDerivation, derivationVersion: derivationVersion)
        return account.publicKey.base58EncodedString
    }

    // Signs a Solana message for the given chain configuration.
    // Returns the base58-encoded Ed25519 detached signature over the UTF-8 message bytes.
    public func signSolanaMessage(
        _ message: String,
        chain: ChainConfig,
        derivationVersion: KeyDerivationVersion = KeyManagerActor.defaultDerivationVersion
    ) async throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.signingFailed("Message is not valid UTF-8")
        }
        try validateSigningIntent(.messageSigning, chain: chain)

        let account = try await solanaAccount(for: chain, intent: .messageSigning, derivationVersion: derivationVersion)
        let signature = try NaclSign.signDetached(message: messageData, secretKey: account.secretKey)
        return Base58.encode(signature)
    }

    // Signs a Solana transfer transaction for the given chain configuration.
    // Builds a SolanaSwift wire-format transaction message, signs it with a
    // chain-scoped derived Ed25519 key, and returns both the signature and
    // serialized transaction so callers do not need to rebuild outside the actor.
    public func signSolanaTransferPayload(
        _ transaction: SolanaTransaction,
        chain: ChainConfig,
        derivationVersion: KeyDerivationVersion = KeyManagerActor.defaultDerivationVersion
    ) async throws -> SolanaSignedPayload {
        try validateSigningIntent(.nativeTransfer, chain: chain)

        let account = try await solanaAccount(for: chain, intent: .nativeTransfer, derivationVersion: derivationVersion)
        let feePayer = account.publicKey

        let instructions = try transaction.instructions.map { instruction in
            let programId = try PublicKey(string: instruction.programId)
            let keys = try instruction.accounts.map { meta in
                let publicKey = try PublicKey(string: meta.publicKey)
                return Account.Meta(publicKey: publicKey, isSigner: meta.isSigner, isWritable: meta.isWritable)
            }
            let dataBytes = try Self.decodeHexString(instruction.data)
            return TransactionInstruction(keys: keys, programId: programId, data: dataBytes)
        }

        var solanaTransaction = Transaction(
            instructions: instructions,
            recentBlockhash: transaction.recentBlockhash,
            feePayer: feePayer
        )
        try solanaTransaction.sign(signers: [account])

        guard let signatureData = solanaTransaction.signatures.first?.signature else {
            throw WalletError.signingFailed("Signed Solana transaction missing signature")
        }

        let serializedTransactionBase64 = try solanaTransaction.serialize().bytes.toBase64()
        return SolanaSignedPayload(
            signature: Base58.encode(signatureData),
            serializedTransactionBase64: serializedTransactionBase64
        )
    }

    // Backward-compatible wrapper for existing call sites that only expect a signature.
    public func signSolanaTransfer(_ transaction: SolanaTransaction, chain: ChainConfig) async throws -> String {
        let payload = try await signSolanaTransferPayload(transaction, chain: chain)
        return payload.signature
    }

    // Derives the SolanaSwift Account (Ed25519 keypair). Defaults to the legacy
    // raw-master-key derivation to preserve existing addresses; pass
    // derivationVersion: .hkdfV1 to opt a chain/intent into the hardened,
    // chain-scoped HKDF derivation instead.
    private func solanaAccount(
        for chain: ChainConfig,
        intent: SigningIntent,
        derivationVersion: KeyDerivationVersion = KeyManagerActor.defaultDerivationVersion
    ) async throws -> Account {
        let seed: Data
        switch derivationVersion {
        case .legacy:
            let masterKey = try await loadRootMasterKey()
            seed = masterKey.count >= 32 ? Data(masterKey.prefix(32)) : masterKey
        case .hkdfV1:
            seed = try await derivedEd25519Seed(
                for: chain,
                family: .solanaEd25519,
                intent: intent
            )
        }
        let keyPair = try NaclSign.KeyPair.keyPair(fromSeed: seed)
        return try Account(secretKey: keyPair.secretKey)
    }

    private func validateSigningIntent(_ intent: SigningIntent, chain: ChainConfig) throws {
        guard !chain.name.isEmpty else {
            throw WalletError.chainConfigurationError("Chain name is required for signing intent \(intent.rawValue)")
        }
    }

    private func loadRootMasterKey() async throws -> Data {
        guard let masterKey = try retrievePrivateKey(for: "masterKey") else {
            throw WalletError.keychainError("Master key not found")
        }
        guard !masterKey.isEmpty else {
            throw WalletError.keychainError("Master key is empty")
        }
        return masterKey
    }

    private func derivationSalt(
        chain: ChainConfig,
        family: ChainSigningFamily,
        intent: SigningIntent
    ) -> Data {
        Data("\(chain.chainId)|\(chain.activeNetwork.rawValue)|\(family.rawValue)|\(intent.rawValue)".utf8)
    }

    private func hkdfDerivedKeyMaterial(
        length: Int,
        chain: ChainConfig,
        family: ChainSigningFamily,
        intent: SigningIntent
    ) async throws -> Data {
        let rootKey = try await loadRootMasterKey()
        let inputKey = SymmetricKey(data: rootKey)
        let salt = derivationSalt(chain: chain, family: family, intent: intent)
        let info = Data("AetherWalletKit.cross-chain-signing.v1".utf8)

        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: info,
            outputByteCount: length
        )
        return derived.withUnsafeBytes { Data($0) }
    }

    private func derivedEd25519Seed(
        for chain: ChainConfig,
        family: ChainSigningFamily,
        intent: SigningIntent
    ) async throws -> Data {
        try await hkdfDerivedKeyMaterial(length: 32, chain: chain, family: family, intent: intent)
    }

    private func derivedSecp256k1Secret(
        for chain: ChainConfig,
        family: ChainSigningFamily,
        intent: SigningIntent
    ) async throws -> Data {
        try await hkdfDerivedKeyMaterial(length: 32, chain: chain, family: family, intent: intent)
    }

    private static func decodeHexString(_ hex: String) throws -> [UInt8] {
        let normalized = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard normalized.count.isMultiple(of: 2) else {
            throw WalletError.signingFailed("Solana instruction data must be even-length hex")
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(normalized.count / 2)
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            let pair = normalized[index..<next]
            guard let byte = UInt8(pair, radix: 16) else {
                throw WalletError.signingFailed("Solana instruction data contains non-hex characters")
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    // Signs a Bitcoin transaction draft for the given chain configuration,
    // producing a broadcastable raw P2PKH transaction (SIGHASH_ALL, DER + low-S).
    func signBitcoinTransaction(
        _ draft: BitcoinTxDraft,
        chain: ChainConfig,
        derivationVersion: KeyDerivationVersion = KeyManagerActor.defaultDerivationVersion
    ) async throws -> String {
        try validateSigningIntent(.nativeTransfer, chain: chain)

        let masterKey: Data
        switch derivationVersion {
        case .legacy:
            let rawMasterKey = try await loadRootMasterKey()
            masterKey = rawMasterKey.count >= 32 ? Data(rawMasterKey.prefix(32)) : rawMasterKey
        case .hkdfV1:
            masterKey = try await derivedSecp256k1Secret(
                for: chain,
                family: .bitcoinSecp256k1,
                intent: .nativeTransfer
            )
        }

        guard !draft.utxos.isEmpty else {
            throw WalletError.signingFailed("No UTXOs provided for Bitcoin transaction")
        }
        guard draft.changeSatoshis >= 0 else {
            throw WalletError.signingFailed("Insufficient funds: inputs do not cover amount + fee")
        }
        guard let publicKey = Utilities.privateToPublic(masterKey, compressed: true) else {
            throw WalletError.signingFailed("Unable to derive Bitcoin public key")
        }

        let toScript = try BitcoinScript.p2pkhScript(forAddress: draft.to)
        let changeScript = try BitcoinScript.p2pkhScript(forAddress: draft.changeAddress)

        var outputs: [BitcoinTxOutput] = [
            BitcoinTxOutput(valueSatoshis: draft.amountInSatoshis, scriptPubKey: toScript)
        ]
        if draft.changeSatoshis > 0 {
            outputs.append(BitcoinTxOutput(valueSatoshis: draft.changeSatoshis, scriptPubKey: changeScript))
        }

        let unsignedInputs = draft.utxos.map {
            BitcoinTxInput(txid: $0.txid, vout: $0.vout, scriptSig: Data(), sequence: 0xFFFFFFFF)
        }

        var signedInputs: [BitcoinTxInput] = []
        for (index, utxo) in draft.utxos.enumerated() {
            guard !utxo.scriptPubKeyHex.isEmpty else {
                throw WalletError.signingFailed("Missing scriptPubKey for UTXO \(utxo.outpoint)")
            }
            let prevScript = Data(hex: utxo.scriptPubKeyHex) // CryptoSwift's Data(hex:) — always succeeds, never optional
            let sighash = BitcoinTransactionBuilder.sighashAll(
                inputs: unsignedInputs,
                outputs: outputs,
                signingIndex: index,
                prevScriptPubKey: prevScript
            )
            let (signature, _) = SECP256K1.signForRecovery(hash: sighash, privateKey: masterKey)
            guard let signature, signature.count >= 64 else {
                throw WalletError.signingFailed("Bitcoin transaction signing failed at input \(index)")
            }
            // signForRecovery returns 65 bytes (r||s||v) for EVM-style recovery;
            // Bitcoin's DER encoding only needs the raw r||s (first 64 bytes).
            let rawSignature = Data(signature.prefix(64))
            let derSignature = try BitcoinScript.derEncode(signature: rawSignature) + Data([0x01]) // SIGHASH_ALL
            let scriptSig = BitcoinScript.pushData(derSignature) + BitcoinScript.pushData(publicKey)
            signedInputs.append(
                BitcoinTxInput(txid: utxo.txid, vout: utxo.vout, scriptSig: scriptSig, sequence: 0xFFFFFFFF)
            )
        }

        let rawTx = BitcoinTransactionBuilder.serialize(inputs: signedInputs, outputs: outputs)
        return rawTx.toHexString()
    }

    // Signs a Bitcoin message for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 signing and message encoding strategy are finalized.
    public func signBitcoinMessage(_ message: String, chain: ChainConfig) async throws -> String {
        guard let rawMasterKey = try retrievePrivateKey(for: "masterKey") else {
            throw WalletError.keychainError("Master key not found")
        }
        let masterKey = rawMasterKey.count >= 32 ? Data(rawMasterKey.prefix(32)) : rawMasterKey
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.signingFailed("Message is not valid UTF-8")
        }
        let hash = Data(SHA256.hash(data: Data(SHA256.hash(data: messageData))))
        let (signature, _) = SECP256K1.signForRecovery(hash: hash, privateKey: masterKey)
        guard let signature else {
            throw WalletError.signingFailed("Bitcoin message signing failed")
        }
        return signature.toHexString()
    }

    // Signs a message for Flow using the account's registered ECDSA_P256 key.
    // Flow's signing algorithm for the default account key is ECDSA on the P-256 curve
    // (secp256r1), distinct from Bitcoin/EVM's secp256k1. This uses the same master key
    // material via P256, matching the generic `sign(data:withKeyIdentifier:)` helper below.
    public func signFlowMessage(_ message: String, chain: ChainConfig, keyIdentifier: String = "masterKey") async throws -> String {
        guard let rawMasterKey = try retrievePrivateKey(for: keyIdentifier) else {
            throw WalletError.keychainError("Master key not found")
        }
        let masterKey = rawMasterKey.count >= 32 ? Data(rawMasterKey.prefix(32)) : rawMasterKey
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.signingFailed("Message is not valid UTF-8")
        }
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: masterKey)
        let signature = try signingKey.signature(for: messageData)
        return signature.rawRepresentation.toHexString()
    }

    // Returns the primary Bitcoin address for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 key derivation and HD path strategy are finalized.
    public func bitcoinAddress(for chain: ChainConfig) async throws -> String {
        guard let rawMasterKey = try retrievePrivateKey(for: "masterKey") else {
            throw WalletError.keychainError("Master key not found")
        }
        let masterKey = rawMasterKey.count >= 32 ? Data(rawMasterKey.prefix(32)) : rawMasterKey
        guard let publicKey = Utilities.privateToPublic(masterKey, compressed: true) else {
            throw WalletError.signingFailed("Unable to derive Bitcoin public key")
        }
        let sha256Hash = Data(SHA256.hash(data: publicKey))
        let hash160 = try RIPEMD160.hash(message: sha256Hash)
        let versionByte: UInt8 = chain.activeNetwork == .testnet ? 0x6f : 0x00
        var payload = Data([versionByte]) + hash160
        let checksum = Data(SHA256.hash(data: Data(SHA256.hash(data: payload)))).prefix(4)
        payload += checksum
        return Base58.encode(payload)
    }

    // Stores a Flow account address (public data) for later balance/transaction lookups.
    // Flow addresses are assigned on-chain at account creation and are not derived from
    // the signing key the way Bitcoin/EVM addresses are, so this must be set explicitly
    // once the corresponding Flow account has been created or discovered.
    public func storeFlowAddress(_ hexAddress: String, requiresBiometrics: Bool = false) throws {
        guard let data = hexAddress.data(using: .utf8) else {
            throw WalletError.signingFailed("Flow address is not valid UTF-8")
        }
        try storageProvider.storeKey(data, for: "flowAddress", requiresBiometrics: requiresBiometrics)
    }

    // Retrieves the previously stored Flow account address, if any.
    public func flowAddress() throws -> String? {
        guard let data = try retrievePrivateKey(for: "flowAddress") else { return nil }
        return String(data: data, encoding: .utf8)
    }

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
        try storageProvider.storeKey(key, for: identifier, requiresBiometrics: requiresBiometrics)
    }

    public func retrievePrivateKey(for identifier: String) throws -> Data? {
        try storageProvider.retrieveKey(for: identifier)
    }

    public func deletePrivateKey(for identifier: String) throws {
        try storageProvider.deleteKey(for: identifier)
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

final class KeyManagerSecureEnclaveStore {
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

final class KeyManagerKeychainStore {
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
