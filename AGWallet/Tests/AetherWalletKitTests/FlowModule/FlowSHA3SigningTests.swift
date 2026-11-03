#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import Testing
@testable import AetherWalletKit

@Suite("Flow P-256 SHA3 signing")
struct FlowSHA3SigningTests {
    @Test("returns a raw 64-byte P1363 signature for Flow signing data")
    func returnsRawP1363Signature() throws {
        let key = P256.Signing.PrivateKey()
        let payload = Data("aether-flow-sha3-signing-test".utf8)

        let signature = try FlowP256SHA3Signer.sign(payload, with: key)

        #expect(signature.count == 64)
        #expect(signature != Data(repeating: 0, count: 64))

        _ = try P256.Signing.ECDSASignature(rawRepresentation: signature)
    }

    @Test("different payloads produce distinct Flow signatures")
    func differentPayloadsProduceDistinctSignatures() throws {
        let key = P256.Signing.PrivateKey()

        let first = try FlowP256SHA3Signer.sign(
            Data("aether-flow-payload-one".utf8),
            with: key
        )
        let second = try FlowP256SHA3Signer.sign(
            Data("aether-flow-payload-two".utf8),
            with: key
        )

        #expect(first.count == 64)
        #expect(second.count == 64)
        #expect(first != second)
    }
}
