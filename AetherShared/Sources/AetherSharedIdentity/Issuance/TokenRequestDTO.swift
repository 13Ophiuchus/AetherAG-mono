//
//  TokenRequestDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct TokenRequestDTO: Equatable, Sendable {
  public let grantType: String
  public let preAuthorizedCode: String?
  public let code: String?
  public let userPin: String?

  public init(
    grantType: String,
    preAuthorizedCode: String? = nil,
    code: String? = nil,
    userPin: String? = nil
  ) {
    self.grantType = grantType
    self.preAuthorizedCode = preAuthorizedCode
    self.code = code
    self.userPin = userPin
  }

  private enum CodingKeys: String, CodingKey {
    case grantType = "grant_type"
    case code
    case userPin = "user_pin"
    case preAuthorizedCodeSpec = "pre-authorized_code"
    case preAuthorizedCodeSnake = "pre_authorized_code"
    case preAuthorizedCodeCamel = "preAuthorizedCode"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.grantType = try container.decode(String.self, forKey: .grantType)
    self.code = try container.decodeIfPresent(String.self, forKey: .code)
    self.userPin = try container.decodeIfPresent(String.self, forKey: .userPin)

    if let value = try container.decodeIfPresent(String.self, forKey: .preAuthorizedCodeSpec),
      !value.isEmpty
    {
      self.preAuthorizedCode = value
    } else if let value = try container.decodeIfPresent(
      String.self, forKey: .preAuthorizedCodeSnake),
      !value.isEmpty
    {
      self.preAuthorizedCode = value
    } else if let value = try container.decodeIfPresent(
      String.self, forKey: .preAuthorizedCodeCamel),
      !value.isEmpty
    {
      self.preAuthorizedCode = value
    } else {
      self.preAuthorizedCode = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(grantType, forKey: .grantType)
    try container.encodeIfPresent(code, forKey: .code)
    try container.encodeIfPresent(userPin, forKey: .userPin)
    try container.encodeIfPresent(preAuthorizedCode, forKey: .preAuthorizedCodeSpec)
  }
}
