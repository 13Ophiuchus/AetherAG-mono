import Foundation
import Web3Core

/// BIP86 derivation path helper for Taproot keypath-spend addresses.
///
/// Standard path: m/86'/coin_type'/account'/change/index
/// - Mainnet coin_type = 0, Testnet = 1
/// - Hardened levels use index | 0x80000000
public enum BIP86 {
    /// Returns the standard BIP86 external receive path for the given network.
    /// e.g. mainnet → m/86'/0'/0'/0/0
    public static func receivePath(coinType: UInt32 = 0, account: UInt32 = 0, index: UInt32 = 0) -> String {
        return "m/86'/\(coinType)'/\(account)'/0/\(index)"
    }

    /// Derives a 32-byte secp256k1 private key scalar at the BIP86 path
    /// from a 64-byte BIP39 seed (entropy + HMAC-SHA512 root).
    public static func derivePrivateKey(
        seed: Data,
        coinType: UInt32 = 0,
        account: UInt32 = 0,
        index: UInt32 = 0
    ) throws -> Data {
        let path = receivePath(coinType: coinType, account: account, index: index)
        guard let node = HDNode(seed: seed)?.derive(path: path, derivePrivateKey: true),
              let privKey = node.privateKey else {
            throw WalletError.signingFailed("BIP86 HD derivation failed for path \(path)")
        }
        return privKey
    }
}
