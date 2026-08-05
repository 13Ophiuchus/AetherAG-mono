import Foundation

public struct VerificationPolicy: Codable, Sendable, Equatable {
  public let requiredClaims: [String]
  public let allowedIssuers: [String]
  public let minimumAssuranceLevel: String
  public let expirationTolerance: TimeInterval

  enum CodingKeys: String, CodingKey {
    case requiredClaims = "required_claims"
    case allowedIssuers = "allowed_issuers"
    case minimumAssuranceLevel = "minimum_assurance_level"
    case expirationTolerance = "expiration_tolerance"
  }

  public init(
    requiredClaims: [String] = [],
    allowedIssuers: [String] = [],
    minimumAssuranceLevel: String = "basic",
    expirationTolerance: TimeInterval = 0
  ) {
    self.requiredClaims = requiredClaims
    self.allowedIssuers = allowedIssuers
    self.minimumAssuranceLevel = minimumAssuranceLevel
    self.expirationTolerance = expirationTolerance
  }
}
