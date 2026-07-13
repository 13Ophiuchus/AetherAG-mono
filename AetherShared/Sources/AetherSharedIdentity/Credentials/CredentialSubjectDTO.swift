import Foundation

public struct CredentialSubjectDTO: Codable, Equatable, Hashable, Sendable {
  public let id: String
  public let email: String?
  public let flowAccount: String?
  public let did: String?
  public let assuranceLevel: String?

  public init(
    id: String,
    email: String? = nil,
    flowAccount: String? = nil,
    did: String? = nil,
    assuranceLevel: String? = nil
  ) {
    self.id = id
    self.email = email
    self.flowAccount = flowAccount
    self.did = did
    self.assuranceLevel = assuranceLevel
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.email = try container.decodeIfPresent(String.self, forKey: .email)
    self.flowAccount = try container.decodeIfPresent(String.self, forKey: .flowAccount)
    self.did = try container.decodeIfPresent(String.self, forKey: .did)
    self.assuranceLevel = try container.decodeIfPresent(String.self, forKey: .assuranceLevel)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(email, forKey: .email)
    try container.encodeIfPresent(flowAccount, forKey: .flowAccount)
    try container.encodeIfPresent(did, forKey: .did)
    try container.encodeIfPresent(assuranceLevel, forKey: .assuranceLevel)
  }

  public enum CodingKeys: String, CodingKey {
    case id
    case email
    case flowAccount
    case did
    case assuranceLevel
  }
}
