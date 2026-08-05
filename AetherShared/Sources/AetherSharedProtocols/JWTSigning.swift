import Foundation

public protocol JWTSigning: Sendable {
    func verify(jws: String) throws -> Data
}
