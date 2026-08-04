import Crypto
import Foundation

/// RFC 2898 PBKDF2 implementation using HMAC-SHA512, replacing CommonCrypto's
/// the CommonCrypto PBKDF for Linux compatibility via swift-crypto.
func pbkdf2(password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
    guard let passwordData = password.data(using: .utf8) else {
        return nil
    }

    let hashLength = 64 // SHA512 digest length in bytes
    let blockCount = Int(ceil(Double(keyByteCount) / Double(hashLength)))

    let key = SymmetricKey(data: passwordData)
    var derivedKey = Data()

    for blockIndex in 1...blockCount {
        var blockIndexBE = UInt32(blockIndex).bigEndian
        var saltWithIndex = salt
        withUnsafeBytes(of: &blockIndexBE) { saltWithIndex.append(contentsOf: $0) }

        var u = Data(HMAC<SHA512>.authenticationCode(for: saltWithIndex, using: key))
        var t = u

        for _ in 1..<rounds {
            u = Data(HMAC<SHA512>.authenticationCode(for: u, using: key))
            for i in 0..<t.count {
                t[i] ^= u[i]
            }
        }

        derivedKey.append(t)
    }

    return derivedKey.prefix(keyByteCount)
}
