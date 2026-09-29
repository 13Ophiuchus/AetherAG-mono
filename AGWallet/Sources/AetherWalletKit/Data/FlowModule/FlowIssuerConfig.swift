import Flow
import Foundation
import Security

/// Configuration for the issuer/payer account that funds and authorizes
/// creation of new Flow accounts. Private key material is loaded from the
/// Keychain by reference — never held as a plaintext string in this struct.
public struct FlowIssuerConfig: Sendable {
    public let address: Flow.Address
    public let keyIndex: Int
    public let proposalKey: Flow.TransactionProposalKey
    /// Keychain lookup identifier — NOT the key itself.
    public let keychainIdentifier: String

    public init(
        address: Flow.Address,
        keyIndex: Int,
        proposalKey: Flow.TransactionProposalKey,
        keychainIdentifier: String
    ) {
        self.address = address
        self.keyIndex = keyIndex
        self.proposalKey = proposalKey
        self.keychainIdentifier = keychainIdentifier
    }

    /// Loads the issuer's private key material from the Keychain at sign
    /// time only. Never store the result beyond the immediate signing call.
    func loadPrivateKeyData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw WalletError.keychainError("Issuer key not found for identifier: \(keychainIdentifier)")
        }
        return data
    }
}
