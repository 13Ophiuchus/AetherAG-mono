//
//  DevTokenRequestDTO.swift
//  AetherSharedIdentity
//

public struct DevTokenRequestDTO: Codable, Sendable {
  public let grantType: String
  public let preAuthorizedCode: String

  public init(
    grantType: String,
    preAuthorizedCode: String
  ) {
    self.grantType = grantType
    self.preAuthorizedCode = preAuthorizedCode
  }

  public enum CodingKeys: String, CodingKey {
    case grantType = "grant_type"
    case preAuthorizedCode = "pre-authorized_code"
  }
}
