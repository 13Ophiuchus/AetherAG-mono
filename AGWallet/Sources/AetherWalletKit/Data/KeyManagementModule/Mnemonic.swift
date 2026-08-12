import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

public enum MnemonicError: Error {
    case entropyGenerationFailed
    case invalidEntropyLength
    case checksumMismatch
    case invalidWordCount
}

public struct Mnemonic {
    public let words: [String]
    public var phrase: String { words.joined(separator: " ") }

    public static func generate(strength: Int = 128) throws -> Mnemonic {
        guard [128, 160, 192, 224, 256].contains(strength) else {
            throw MnemonicError.invalidEntropyLength
        }
        let byteCount = strength / 8
        var entropy = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &entropy)
        guard status == errSecSuccess else { throw MnemonicError.entropyGenerationFailed }
        return try fromEntropy(entropy)
    }

    public static func fromEntropy(_ entropy: [UInt8]) throws -> Mnemonic {
        guard [16, 20, 24, 28, 32].contains(entropy.count) else {
            throw MnemonicError.invalidEntropyLength
        }
        let hash = Array(SHA256.hash(data: Data(entropy)))
        let checksumBits = entropy.count * 8 / 32
        let checksumByte = hash[0]
        var bits: [Bool] = []
        for byte in entropy {
            for i in (0..<8).reversed() { bits.append((byte >> i) & 1 == 1) }
        }
        for i in (8 - checksumBits..<8).reversed() {
            bits.append((checksumByte >> i) & 1 == 1)
        }
        let wordCount = bits.count / 11
        var words: [String] = []
        let wordlist = BIP39Wordlist.english
        for i in 0..<wordCount {
            var index = 0
            for j in 0..<11 { if bits[i * 11 + j] { index |= (1 << (10 - j)) } }
            words.append(wordlist[index])
        }
        return Mnemonic(words: words)
    }

    public func validateChecksum() throws {
        let wordlist = BIP39Wordlist.english
        var bits: [Bool] = []
        for word in words {
            guard let index = wordlist.firstIndex(of: word) else {
                throw MnemonicError.checksumMismatch
            }
            for i in (0..<11).reversed() { bits.append((index >> i) & 1 == 1) }
        }
        let totalBits = bits.count
        let checksumBits = totalBits / 33
        let entropyBits = totalBits - checksumBits
        var entropy = [UInt8]()
        for i in stride(from: 0, to: entropyBits, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 { if bits[i + j] { byte |= (1 << (7 - j)) } }
            entropy.append(byte)
        }
        let hash = Array(SHA256.hash(data: Data(entropy)))
        let expectedChecksumByte = hash[0]
        var computedChecksum: UInt8 = 0
        for i in 0..<checksumBits {
            if bits[entropyBits + i] { computedChecksum |= (1 << (checksumBits - 1 - i)) }
        }
        let mask: UInt8 = ~((1 << (8 - checksumBits)) - 1)
        guard (expectedChecksumByte & mask) >> (8 - checksumBits) == computedChecksum else {
            throw MnemonicError.checksumMismatch
        }
    }
public func seed(passphrase: String = "") -> Data {
        let password = phrase.data(using: .utf8)!
        let salt = ("mnemonic" + passphrase).data(using: .utf8)!
#if canImport(CommonCrypto)
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
#else
        // Portable PBKDF2-HMAC-SHA512 (BIP39 spec: 2048 iterations, 64-byte output),
        // using swift-crypto's HMAC since CommonCrypto is Darwin-only.
        return Mnemonic.pbkdf2HMACSHA512(password: password, salt: salt, iterations: 2048, keyLength: 64)
#endif
    }

#if !canImport(CommonCrypto)
    private static func pbkdf2HMACSHA512(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        let hLen = 64 // SHA512 output size
        let blockCount = Int(ceil(Double(keyLength) / Double(hLen)))
        var derivedKey = Data()
        let key = SymmetricKey(data: password)

        for blockIndex in 1...blockCount {
            var blockIndexBE = UInt32(blockIndex).bigEndian
            var saltWithBlockIndex = salt
            withUnsafeBytes(of: &blockIndexBE) { saltWithBlockIndex.append(contentsOf: $0) }

            var u = Data(HMAC<SHA512>.authenticationCode(for: saltWithBlockIndex, using: key))
            var t = u

            if iterations > 1 {
                for _ in 2...iterations {
                    u = Data(HMAC<SHA512>.authenticationCode(for: u, using: key))
                    for i in 0..<t.count {
                        t[i] ^= u[i]
                    }
                }
            }
            derivedKey.append(t)
        }

        return derivedKey.prefix(keyLength)
    }
#endif
}
