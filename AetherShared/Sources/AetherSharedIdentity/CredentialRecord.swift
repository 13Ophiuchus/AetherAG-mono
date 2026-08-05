import Foundation

public struct CredentialRecord: Codable, Sendable {
    public let id: UUID
    public let credentialID: String
    public let subjectDID: String
    public let issuerDID: String
    public let credentialJSON: String
    public let issuedAt: Date
    public let expiresAt: Date?
    public let revokedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        credentialID: String,
        subjectDID: String,
        issuerDID: String,
        credentialJSON: String,
        issuedAt: Date,
        expiresAt: Date?,
        revokedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.credentialID = credentialID
        self.subjectDID = subjectDID
        self.issuerDID = issuerDID
        self.credentialJSON = credentialJSON
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
