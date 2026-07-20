import Foundation
import AetherSharedIdentity

public protocol CredentialVerifying: Sendable {
    /// Verify a raw attestation string (e.g. Secure Enclave attestation).
    /// Implementations should throw to reject the credential request.
    func verify(_ attestation: String?) async throws
}

public protocol VerificationRequestHandling: Sendable {
    func create(_ record: VerificationRequestRecord) async throws -> VerificationRequestRecord
    func find(id: UUID) async throws -> VerificationRequestRecord?
    func updateStatus(id: UUID, status: VerificationStatus) async throws
}
