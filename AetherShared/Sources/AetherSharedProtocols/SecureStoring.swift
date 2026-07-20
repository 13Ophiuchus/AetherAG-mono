import Foundation
import AetherSharedIdentity

public protocol SecureStoring: Sendable {
    func create(_ session: IssuanceSessionRecord) async throws -> IssuanceSessionRecord
    func save(_ session: IssuanceSession) async throws
    func findByPreAuthorizedCode(_ code: String) async throws -> IssuanceSession?
    func findByAccessToken(_ accessToken: String) async throws -> IssuanceSession?
    func findByCNonce(_ cNonce: String) async throws -> IssuanceSession?
    func markPreAuthorizedCodeUsed(
        _sessionID id: UUID,
        usedAt: Date
    ) async throws
    func update(_ session: IssuanceSessionRecord) async throws
    func updateAccessToken(
        _sessionID id: UUID,
        accessToken: String,
        accessTokenExpiresAt: Date,
        cNonce: String,
        cNonceExpiresAt: Date
    ) async throws
}
