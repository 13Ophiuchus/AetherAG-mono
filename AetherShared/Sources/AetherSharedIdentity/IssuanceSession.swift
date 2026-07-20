import Foundation

public struct IssuanceSession: Codable, Sendable {
    public var id: UUID?
    public var subjectDID: String
    public var subjectPublicJWK: [String: String]?
    public var email: String
    public var flowAccount: String
    public var preAuthorizedCode: String
    public var preAuthorizedCodeExpiresAt: Date
    public var preAuthorizedCodeUsedAt: Date?
    public var accessToken: String?
    public var accessTokenExpiresAt: Date?
    public var cNonce: String?
    public var cNonceExpiresAt: Date?
    public var expiresAt: Date
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: UUID? = nil,
        subjectDID: String,
        subjectPublicJWK: [String: String]? = nil,
        email: String,
        flowAccount: String,
        preAuthorizedCode: String,
        preAuthorizedCodeExpiresAt: Date,
        preAuthorizedCodeUsedAt: Date? = nil,
        accessToken: String? = nil,
        accessTokenExpiresAt: Date? = nil,
        cNonce: String? = nil,
        cNonceExpiresAt: Date? = nil,
        expiresAt: Date,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
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

    public enum CodingKeys: String, CodingKey {
        case id
        case subjectDID = "subject_did"
        case subjectPublicJWK = "subject_public_jwk"
        case email
        case flowAccount = "flow_account"
        case preAuthorizedCode = "pre_authorized_code"
        case preAuthorizedCodeExpiresAt = "pre_authorized_code_expires_at"
        case preAuthorizedCodeUsedAt = "pre_authorized_code_used_at"
        case accessToken = "access_token"
        case accessTokenExpiresAt = "access_token_expires_at"
        case cNonce = "c_nonce"
        case cNonceExpiresAt = "c_nonce_expires_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
