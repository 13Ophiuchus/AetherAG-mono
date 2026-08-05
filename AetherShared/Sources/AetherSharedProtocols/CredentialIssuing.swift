import Foundation
import AetherSharedIdentity

public protocol CredentialIssuing: Sendable {
    func findByCredentialID(_ credentialID: String) async throws -> CredentialRecord?
    func findBySubjectDID(_ subjectDID: String) async throws -> [CredentialRecord]
    func save(_ record: CredentialRecord) async throws
    func update(_ record: CredentialRecord) async throws
}
