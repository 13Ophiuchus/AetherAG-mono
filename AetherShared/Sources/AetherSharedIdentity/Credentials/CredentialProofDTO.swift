import Foundation

public struct CredentialProofDTO: Codable, Equatable, Hashable, Sendable {
  public let type: String?
  public let created: String?
  public let proofPurpose: String?
  public let verificationMethod: String?
  public let proofValue: String?

  public init(
    type: String? = nil,
    created: String? = nil,
    proofPurpose: String? = nil,
    verificationMethod: String? = nil,
    proofValue: String? = nil
  ) {
    self.type = type
    self.created = created
    self.proofPurpose = proofPurpose
    self.verificationMethod = verificationMethod
    self.proofValue = proofValue
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.type = try container.decodeIfPresent(String.self, forKey: .type)
    self.created = try container.decodeIfPresent(String.self, forKey: .created)
    self.proofPurpose = try container.decodeIfPresent(String.self, forKey: .proofPurpose)
    self.verificationMethod = try container.decodeIfPresent(
      String.self, forKey: .verificationMethod)
    self.proofValue = try container.decodeIfPresent(String.self, forKey: .proofValue)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(created, forKey: .created)
    try container.encodeIfPresent(proofPurpose, forKey: .proofPurpose)
    try container.encodeIfPresent(verificationMethod, forKey: .verificationMethod)
    try container.encodeIfPresent(proofValue, forKey: .proofValue)
  }

  public enum CodingKeys: String, CodingKey {
    case type
    case created
    case proofPurpose
    case verificationMethod
    case proofValue
  }
}
