import Foundation

public struct IssuanceSessionRecord: Codable, Sendable {
    public let id: UUID
    public let subjectDID: String
    public let subjectPublicJWK: [String: String]?
    public let email: String
    public let flowAccount: String
    public let preAuthorizedCode: String
    public let preAuthorizedCodeExpiresAt: Date
    public let preAuthorizedCodeUsedAt: Date?
    public let accessToken: String?
    public let accessTokenExpiresAt: Date?
    public let cNonce: String?
    public let cNonceExpiresAt: Date?
    public let expiresAt: Date
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        subjectDID: String,
        subjectPublicJWK: [String: String]?,
        email: String,
        flowAccount: String,
        preAuthorizedCode: String,
        preAuthorizedCodeExpiresAt: Date,
        preAuthorizedCodeUsedAt: Date?,
        accessToken: String?,
        accessTokenExpiresAt: Date?,
        cNonce: String?,
        cNonceExpiresAt: Date?,
        expiresAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.subjectDID = subjectDID
        self.subjectPublicJWK = subjectPublicJWK
        self.email = email
        self.flowAccount = flowAccount
        self.preAuthorizedCode = preAuthorizedCode
        self.preAuthorizedCodeExpiresAt = preAuthorizedCodeExpiresAt
        self.preAuthorizedCodeUsedAt = preAuthorizedCodeUsedAt
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.cNonce = cNonce
        self.cNonceExpiresAt = cNonceExpiresAt
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
