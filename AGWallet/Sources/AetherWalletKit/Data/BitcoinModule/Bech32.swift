//
//  Bech32.swift
//  AGWallet
//
//  BIP173 (Bech32, used by SegWit v0 / P2WPKH, P2WSH) and
//  BIP350 (Bech32m, used by SegWit v1+ / Taproot P2TR) encoding.
//
//  Pure data-transform utility — no key material, no signing, no I/O.
//  Reference: https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki
//             https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki
//

import Foundation

/// The witness-version-dependent checksum constant distinguishing Bech32 (BIP173)
/// from Bech32m (BIP350). SegWit v0 (P2WPKH/P2WSH) uses `.bech32`; SegWit v1+
/// (Taproot/P2TR) uses `.bech32m`.
enum Bech32Encoding {
    case bech32
    case bech32m

    fileprivate var checksumConstant: UInt32 {
        switch self {
        case .bech32: return 1
        case .bech32m: return 0x2bc8_30a3
        }
    }
}

enum Bech32Error: Error, Equatable {
    case invalidHRP
    case invalidCharacter
    case invalidChecksum
    case invalidLength
    case mixedCase
    case invalidWitnessVersion
    case invalidWitnessProgramLength
    case dataConversionFailed
}

/// Bech32 / Bech32m encoder-decoder for SegWit witness addresses.
///
/// This type only implements the generic Bech32/Bech32m string codec plus the
/// SegWit-specific witness-version + program packing described in BIP173/BIP350.
/// It intentionally does not know about P2WPKH vs P2WSH vs P2TR semantics —
/// callers supply the witness version and raw program bytes (hash160 for
/// P2WPKH, x-only pubkey for P2TR, etc.).
enum Bech32 {
    private static let charset: [Character] = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let charsetMap: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (index, char) in charset.enumerated() {
            map[char] = UInt8(index)
        }
        return map
    }()

    // MARK: - Core Bech32 / Bech32m string codec (BIP173 / BIP350)

    /// Encodes an human-readable part (hrp) and 5-bit word array into a Bech32
    /// or Bech32m string, per the `encoding` parameter.
    static func encode(hrp: String, words: [UInt8], encoding: Bech32Encoding) throws -> String {
        guard !hrp.isEmpty, hrp == hrp.lowercased() || hrp == hrp.uppercased() else {
            throw Bech32Error.invalidHRP
        }
        let lowerHRP = hrp.lowercased()
        let checksum = createChecksum(hrp: lowerHRP, words: words, encoding: encoding)
        let combined = words + checksum
        var result = lowerHRP + "1"
        for word in combined {
            guard word < 32 else { throw Bech32Error.invalidCharacter }
            result.append(charset[Int(word)])
        }
        return result
    }

    /// Decodes a Bech32 or Bech32m string into its human-readable part, 5-bit
    /// word array (checksum stripped), and which variant it was encoded with.
    static func decode(_ input: String) throws -> (hrp: String, words: [UInt8], encoding: Bech32Encoding) {
        guard input.count <= 90 else { throw Bech32Error.invalidLength }

        let hasLower = input.contains(where: { $0.isLowercase })
        let hasUpper = input.contains(where: { $0.isUppercase })
        guard !(hasLower && hasUpper) else { throw Bech32Error.mixedCase }

        let lowered = input.lowercased()
        guard let separatorIndex = lowered.lastIndex(of: "1") else { throw Bech32Error.invalidCharacter }

        let hrp = String(lowered[lowered.startIndex..<separatorIndex])
        let dataPart = String(lowered[lowered.index(after: separatorIndex)...])

        guard !hrp.isEmpty, dataPart.count >= 6 else { throw Bech32Error.invalidLength }

        var words: [UInt8] = []
        words.reserveCapacity(dataPart.count)
        for char in dataPart {
            guard let value = charsetMap[char] else { throw Bech32Error.invalidCharacter }
            words.append(value)
        }

        let payload = Array(words.dropLast(6))
        let checksum = Array(words.suffix(6))

        if verifyChecksum(hrp: hrp, words: payload, checksum: checksum, encoding: .bech32) {
            return (hrp, payload, .bech32)
        }
        if verifyChecksum(hrp: hrp, words: payload, checksum: checksum, encoding: .bech32m) {
            return (hrp, payload, .bech32m)
        }
        throw Bech32Error.invalidChecksum
    }

    // MARK: - SegWit witness address helpers (BIP173 / BIP350 section "Segwit address format")

    /// Encodes a SegWit witness program (e.g. hash160 for P2WPKH v0, sha256 for
    /// P2WSH v0, or a 32-byte x-only pubkey for P2TR v1) into a witness address.
    ///
    /// - Parameters:
    ///   - hrp: Human-readable prefix ("bc" for mainnet, "tb" for testnet/signet,
    ///     "bcrt" for regtest).
    ///   - witnessVersion: 0 for P2WPKH/P2WSH (Bech32), 1 for P2TR (Bech32m).
    ///     Valid range is 0...16 per BIP173.
    ///   - program: Raw witness program bytes. 20 bytes for P2WPKH, 32 bytes for
    ///     P2WSH or P2TR.
    static func encodeSegwitAddress(hrp: String, witnessVersion: UInt8, program: [UInt8]) throws -> String {
        guard witnessVersion <= 16 else { throw Bech32Error.invalidWitnessVersion }
        guard (2...40).contains(program.count) else { throw Bech32Error.invalidWitnessProgramLength }
        // BIP173 §"Segwit address format": v0 must be 20 or 32 bytes exactly.
        if witnessVersion == 0 {
            guard program.count == 20 || program.count == 32 else {
                throw Bech32Error.invalidWitnessProgramLength
            }
        }

        guard let programWords = convertBits(program, fromBits: 8, toBits: 5, pad: true) else {
            throw Bech32Error.dataConversionFailed
        }
        let words = [witnessVersion] + programWords
        let encoding: Bech32Encoding = witnessVersion == 0 ? .bech32 : .bech32m
        return try encode(hrp: hrp, words: words, encoding: encoding)
    }

    /// Decodes a SegWit witness address into its witness version and raw program
    /// bytes, validating that the encoding variant (Bech32 vs Bech32m) matches
    /// the witness version per BIP350 (v0 must use Bech32, v1+ must use Bech32m).
    static func decodeSegwitAddress(_ address: String) throws -> (hrp: String, witnessVersion: UInt8, program: [UInt8]) {
        let (hrp, words, encoding) = try decode(address)
        guard let versionWord = words.first else { throw Bech32Error.invalidLength }
        let witnessVersion = versionWord
        guard witnessVersion <= 16 else { throw Bech32Error.invalidWitnessVersion }

        let expectedEncoding: Bech32Encoding = witnessVersion == 0 ? .bech32 : .bech32m
        guard encoding == expectedEncoding else { throw Bech32Error.invalidChecksum }

        guard let program = convertBits(Array(words.dropFirst()), fromBits: 5, toBits: 8, pad: false) else {
            throw Bech32Error.dataConversionFailed
        }
        guard (2...40).contains(program.count) else { throw Bech32Error.invalidWitnessProgramLength }
        if witnessVersion == 0 {
            guard program.count == 20 || program.count == 32 else {
                throw Bech32Error.invalidWitnessProgramLength
            }
        }
        return (hrp, witnessVersion, program)
    }

    // MARK: - Internal checksum machinery (BIP173 / BIP350 reference implementation)

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        let generator: [UInt32] = [0x3b6a_57b2, 0x2650_8e6d, 0x1ea1_19fa, 0x3d42_33dd, 0x2a14_62b3]
        var chk: UInt32 = 1
        for value in values {
            let top = chk >> 25
            chk = (chk & 0x1ff_ffff) << 5 ^ UInt32(value)
            for i in 0..<5 {
                if (top >> UInt32(i)) & 1 == 1 {
                    chk ^= generator[i]
                }
            }
        }
        return chk
    }

    private static func hrpExpand(_ hrp: String) -> [UInt8] {
        let bytes = Array(hrp.utf8)
        var result: [UInt8] = bytes.map { $0 >> 5 }
        result.append(0)
        result.append(contentsOf: bytes.map { $0 & 31 })
        return result
    }

    private static func createChecksum(hrp: String, words: [UInt8], encoding: Bech32Encoding) -> [UInt8] {
        let values = hrpExpand(hrp) + words + [0, 0, 0, 0, 0, 0]
        let polymodResult = polymod(values) ^ encoding.checksumConstant
        var checksum: [UInt8] = []
        for i in 0..<6 {
            checksum.append(UInt8((polymodResult >> (5 * (5 - i))) & 31))
        }
        return checksum
    }

    private static func verifyChecksum(hrp: String, words: [UInt8], checksum: [UInt8], encoding: Bech32Encoding) -> Bool {
        let values = hrpExpand(hrp) + words + checksum
        return polymod(values) == encoding.checksumConstant
    }

    /// Converts a byte array between arbitrary bit-widths (8-bit bytes <-> 5-bit
    /// Bech32 words), per BIP173's `convertbits` reference algorithm.
    private static func convertBits(_ data: [UInt8], fromBits: Int, toBits: Int, pad: Bool) -> [UInt8]? {
        var acc: Int = 0
        var bits: Int = 0
        var result: [UInt8] = []
        let maxValue = (1 << toBits) - 1
        let maxAcc = (1 << (fromBits + toBits - 1)) - 1

        for value in data {
            let v = Int(value)
            if v < 0 || (v >> fromBits) != 0 { return nil }
            acc = ((acc << fromBits) | v) & maxAcc
            bits += fromBits
            while bits >= toBits {
                bits -= toBits
                result.append(UInt8((acc >> bits) & maxValue))
            }
        }

        if pad {
            if bits > 0 {
                result.append(UInt8((acc << (toBits - bits)) & maxValue))
            }
        } else if bits >= fromBits || ((acc << (toBits - bits)) & maxValue) != 0 {
            return nil
        }

        return result
    }
}
