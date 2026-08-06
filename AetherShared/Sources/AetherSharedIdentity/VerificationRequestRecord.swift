import Foundation

public struct VerificationRequestRecord: Codable, Sendable {
    public let id: UUID
    public let challenge: String
    public let domain: String
    public let requesterDID: String
    public let subjectDID: String?
    public let status: VerificationStatus
    public let policy: VerificationPolicy
    public let submission: Data?
    public let createdAt: Date
    public let updatedAt: Date?

    // OID4VP fields
    public let nonce: String?
    public let jti: String?
    public let responseUri: String?
    public let clientId: String?
    public let presentationDefinition: Data?
    public let expiresAt: Date?

    public init(
        id: UUID,
        challenge: String,
        domain: String,
        requesterDID: String,
        subjectDID: String?,
        status: VerificationStatus,
        policy: VerificationPolicy,
        submission: Data?,
        createdAt: Date,
        updatedAt: Date?,
        nonce: String? = nil,
        jti: String? = nil,
        responseUri: String? = nil,
        clientId: String? = nil,
        presentationDefinition: Data? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.challenge = challenge
        self.domain = domain
        self.requesterDID = requesterDID
        self.subjectDID = subjectDID
        self.status = status
        self.policy = policy
        self.submission = submission
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.nonce = nonce
        self.jti = jti
        self.responseUri = responseUri
        self.clientId = clientId
        self.presentationDefinition = presentationDefinition
        self.expiresAt = expiresAt
    }
}
