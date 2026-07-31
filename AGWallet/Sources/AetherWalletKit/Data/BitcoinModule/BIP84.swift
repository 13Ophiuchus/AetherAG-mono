import Foundation
import Web3Core

/// BIP84 derivation path helper for Native SegWit P2WPKH addresses.
///
/// Standard path: m/84'/coin_type'/account'/change/index
/// - Mainnet coin_type = 0, Testnet = 1
public enum BIP84 {
    public static func receivePath(coinType: UInt32 = 0, account: UInt32 = 0, index: UInt32 = 0) -> String {
        "m/84'/\(coinType)'/\(account)'/0/\(index)"
    }

    /// Derives a 33-byte compressed secp256k1 public key at the BIP84 path from a BIP39 seed.
    public static func derivePublicKey(
        seed: Data,
        coinType: UInt32 = 0,
        account: UInt32 = 0,
        index: UInt32 = 0
    ) throws -> Data {
        let path = receivePath(coinType: coinType, account: account, index: index)
        guard let node = HDNode(seed: seed)?.derive(path: path, derivePrivateKey: true),
              let privKey = node.privateKey,
              let pubKey = Utilities.privateToPublic(privKey, compressed: true) else {
            throw WalletError.signingFailed("BIP84 HD derivation failed for path \(path)")
        }
        return pubKey
    }
}
