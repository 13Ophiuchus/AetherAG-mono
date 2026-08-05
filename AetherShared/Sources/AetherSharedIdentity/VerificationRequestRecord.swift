import Foundation

public struct VerificationRequestRecord: Codable, Sendable {
    public let id: UUID
    public let challenge: String
    public let domain: String
    public let requesterDID: String
    public let subjectDID: String?
    public let status: VerificationStatus
    public let policy: VerificationPolicy
    public let submission: VerificationSubmissionRequest?
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: UUID,
        challenge: String,
        domain: String,
        requesterDID: String,
        subjectDID: String?,
        status: VerificationStatus,
        policy: VerificationPolicy,
        submission: VerificationSubmissionRequest?,
        createdAt: Date,
        updatedAt: Date?
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
    }
}
