import Foundation
import CryptoSwift
#if canImport(CryptoKit)
import CryptoKit

/// Wraps a precomputed SHA3-256 digest so CryptoKit signs it directly
/// instead of re-hashing with SHA-256.
struct AetherSHA3Digest: CryptoKit.Digest {
    typealias Element = UInt8
    static var byteCount: Int { 32 }
    private let storage: [UInt8]

    init(bytes: [UInt8]) {
        precondition(bytes.count == Self.byteCount, "SHA3-256 digest must be 32 bytes")
        storage = bytes
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeBytes(body)
    }
    func makeIterator() -> Array<UInt8>.Iterator { storage.makeIterator() }
    var description: String { storage.map { String(format: "%02x", $0) }.joined() }
    static func == (lhs: AetherSHA3Digest, rhs: AetherSHA3Digest) -> Bool { lhs.storage == rhs.storage }
    func hash(into hasher: inout Hasher) { hasher.combine(storage) }
}

enum FlowP256SHA3Signer {
    /// ECDSA P-256 over SHA3-256, returned as raw r||s (P1363), matching Flow keys
    /// registered as ECDSA_P256 + SHA3_256.
    static func sign(_ data: Data, with key: P256.Signing.PrivateKey) throws -> Data {
        let digest = AetherSHA3Digest(bytes: Array(data).sha3(.sha256))
        return try key.signature(for: digest).rawRepresentation
    }
}
#endif
