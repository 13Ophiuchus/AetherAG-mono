//
//  BitcoinAddressType.swift
//  AGWallet
//
//  Address-type selector for Bitcoin address derivation, orthogonal to
//  KeyDerivationVersion (which governs key material derivation, not
//  script/encoding format). Legacy P2PKH remains the default to preserve
//  existing wallet behavior; P2WPKH (BIP84) is opt-in via this parameter.
//

import Foundation

/// Which Bitcoin script/address format to derive and encode for.
public enum BitcoinAddressType: String, Sendable, CaseIterable {
    /// Legacy Pay-to-PubKey-Hash (Base58Check, "1..." mainnet).
    case p2pkh
    /// Native SegWit v0 Pay-to-Witness-PubKey-Hash (Bech32, "bc1q..." mainnet).
    case p2wpkh
    /// Taproot Pay-to-Taproot (Bech32m, "bc1p..." mainnet). Not yet implemented —
    /// reserved for the next milestone phase.
    case p2tr
}

/// Maps a `ChainNetwork` to the Bech32 human-readable prefix (HRP) used for
/// SegWit v0/v1 witness addresses, per BIP173 §"Segwit address format" and the
/// network conventions used by Bitcoin Core (`bc`, `tb`, `bcrt`).
enum BitcoinNetworkHRP {
    static func hrp(for network: ChainNetwork) -> String {
        switch network {
        case .mainnet:
            return "bc"
        case .testnet, .signet:
            return "tb"
        case .regtest, .devnet, .local:
            return "bcrt"
        }
    }
}
