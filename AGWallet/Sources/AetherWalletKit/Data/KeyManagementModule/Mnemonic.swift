import Foundation
import CryptoKit

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
        let hash = SHA256.hash(data: Data(entropy))
        let checksumBits = entropy.count * 8 / 32
        let checksumByte = hash.first!
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
        let hash = SHA256.hash(data: Data(entropy))
        let expectedChecksumByte = hash.first!
        var computedChecksum: UInt8 = 0
        for i in 0..<checksumBits {
            if bits[entropyBits + i] { computedChecksum |= (1 << (checksumBits - 1 - i)) }
        }
        let mask: UInt8 = ~((1 << (8 - checksumBits)) - 1)
        guard (expectedChecksumByte & mask) >> (8 - checksumBits) == computedChecksum else {
            throw MnemonicError.checksumMismatch
        }
    }
}
