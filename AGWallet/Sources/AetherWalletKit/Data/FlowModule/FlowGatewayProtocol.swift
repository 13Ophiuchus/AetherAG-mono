import Flow
import CryptoKit
import Foundation

public protocol FlowGatewayProtocol: Sendable {
    func sendTransaction(
        script: Data,
        arguments: [Flow.Argument],
        gasLimit: UInt64,
        proposalKey: Flow.TransactionProposalKey,
        payer: Flow.Address,
        authorizers: [Flow.Address],
        envelopeSigner: any FlowSigner
    ) async throws -> Flow.ID

    func transactionResult(id: Flow.ID) async throws -> Flow.TransactionResult
}

public final class LiveFlowGateway: FlowGatewayProtocol {
    private let flowClient: Flow
    private let chainID: Flow.ChainID

    public init(chainID: Flow.ChainID) {
        self.chainID = chainID
        self.flowClient = Flow()
    }

    public func sendTransaction(
        script: Data,
        arguments: [Flow.Argument],
        gasLimit: UInt64,
        proposalKey: Flow.TransactionProposalKey,
        payer: Flow.Address,
        authorizers: [Flow.Address],
        envelopeSigner: any FlowSigner
    ) async throws -> Flow.ID {
        // TODO: Confirm this matches your installed Flow SDK's actual
        // transaction builder API before relying on this in production.
        fatalError("Implement against your installed Flow SDK's transaction builder API")
    }

    public func transactionResult(id: Flow.ID) async throws -> Flow.TransactionResult {
        try await flowClient.accessAPI.getTransactionResultById(id: id)
    }
}

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
