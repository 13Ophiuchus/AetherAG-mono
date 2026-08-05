//
//  TokenResponseDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct TokenResponseDTO: Equatable, Sendable, Codable {
  public let accessToken: String
  public let tokenType: String
  public let expiresIn: Int
  public let cNonce: String?
  public let cNonceExpiresIn: Int?

  public init(
    accessToken: String,
    tokenType: String = "Bearer",
    expiresIn: Int,
    cNonce: String? = nil,
    cNonceExpiresIn: Int? = nil
  ) {
    self.accessToken = accessToken
    self.tokenType = tokenType
    self.expiresIn = expiresIn
    self.cNonce = cNonce
    self.cNonceExpiresIn = cNonceExpiresIn
  }

  public enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case expiresIn = "expires_in"
    case cNonce = "c_nonce"
    case cNonceExpiresIn = "c_nonce_expires_in"
  }
}

