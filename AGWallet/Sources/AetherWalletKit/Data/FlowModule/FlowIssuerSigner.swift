import Flow
import CryptoKit
import Foundation

struct FlowIssuerSigner: FlowSigner {
    let issuerConfig: FlowIssuerConfig

    var address: Flow.Address { issuerConfig.address }
    var keyIndex: Int { issuerConfig.keyIndex }

    func sign(signableData: Data, transaction: Flow.Transaction?) async throws -> Data {
        let keyData = try issuerConfig.loadPrivateKeyData()
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        let digest = SHA256.hash(data: signableData)
        let signature = try signingKey.signature(for: digest)
        return signature.rawRepresentation
    }
}

// MARK: - Local hex decoding

/// Minimal, dependency-free hex-string decoder. Verified no such initializer
/// exists elsewhere in this codebase or its accessible dependencies.
private extension Data {
    init?(hexEncoded hex: String) {
        let cleaned = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard cleaned.count % 2 == 0 else { return nil }

        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)

        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }
        self = Data(bytes)
    }
}
