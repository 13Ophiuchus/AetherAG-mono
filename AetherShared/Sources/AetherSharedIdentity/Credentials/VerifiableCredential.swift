import Foundation
import AetherSharedCore

public struct VerifiableCredential: Codable, Identifiable, Sendable {
  public let id: String
  public let context: [String]
  public let type: [String]
  public var issuer: String
  public let issuanceDate: String
  public let expirationDate: String?
  public let credentialSubject: CredentialSubject
  public let proof: CredentialProof

  enum CodingKeys: String, CodingKey {
    case id
    case context = "@context"
    case type
    case issuer
    case issuanceDate
    case expirationDate
    case credentialSubject
    case proof
  }

  public init(
    id: String,
    context: [String],
    type: [String],
    issuer: String,
    issuanceDate: String,
    expirationDate: String?,
    credentialSubject: CredentialSubject,
    proof: CredentialProof
  ) {
    self.id = id
    self.context = context
    self.type = type
    self.issuer = issuer
    self.issuanceDate = issuanceDate
    self.expirationDate = expirationDate
    self.credentialSubject = credentialSubject
    self.proof = proof
  }

  public struct CredentialSubject: Codable, Sendable {
    public let id: String
    public let claims: [String: String]

    public var email: String? { claims["email"] }
    public var flowAccount: String? { claims["flowAccount"] }
    public var did: String? { claims["did"] }
    public var assuranceLevel: String? { claims["assuranceLevel"] }

    public init(id: String, claims: [String: String]) {
      self.id = id
      self.claims = claims
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

      var subjectID = ""
      var extractedClaims: [String: String] = [:]

      for key in container.allKeys {
        if key.stringValue == "id" {
          subjectID = try container.decode(String.self, forKey: key)
        } else if let value = try? container.decode(String.self, forKey: key) {
          extractedClaims[key.stringValue] = value
        }
      }

      self.id = subjectID
      self.claims = extractedClaims
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: DynamicCodingKeys.self)

      try container.encode(id, forKey: DynamicCodingKeys("id"))

      for (key, value) in claims {
        try container.encode(value, forKey: DynamicCodingKeys(key))
      }
    }
  }

  public struct CredentialProof: Codable, Sendable {
    public let type: String
    public let created: String
    public let proofPurpose: String
    public let verificationMethod: String
    public let proofValue: String

    enum CodingKeys: String, CodingKey {
      case type
      case created
      case proofPurpose = "proof_purpose"
      case verificationMethod
      case proofValue = "proof_value"
    }

    public init(
      type: String,
      created: String,
      proofPurpose: String,
      verificationMethod: String,
      proofValue: String
    ) {
      self.type = type
      self.created = created
      self.proofPurpose = proofPurpose
      self.verificationMethod = verificationMethod
      self.proofValue = proofValue
    }
  }
}
