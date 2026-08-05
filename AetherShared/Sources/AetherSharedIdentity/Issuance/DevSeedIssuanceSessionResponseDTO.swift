//
//  DevSeedIssuanceSessionResponseDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct DevSeedIssuanceSessionResponseDTO: Codable, Equatable, Sendable {
  public let created: Bool
  public let id: UUID?
  public let subjectDID: String
  public let email: String
  public let flowAccount: String
  public let preAuthorizedCode: String
  public let preAuthorizedCodeExpiresAt: Date?
  public let expiresAt: Date
  public let tokenRequest: DevTokenRequestDTO
  public let message: String

  public init(
    created: Bool,
    id: UUID?,
    subjectDID: String,
    email: String,
    flowAccount: String,
    preAuthorizedCode: String,
    preAuthorizedCodeExpiresAt: Date?,
    expiresAt: Date,
    tokenRequest: DevTokenRequestDTO,
    message: String
  ) {
    self.created = created
    self.id = id
    self.subjectDID = subjectDID
    self.email = email
    self.flowAccount = flowAccount
    self.preAuthorizedCode = preAuthorizedCode
    self.preAuthorizedCodeExpiresAt = preAuthorizedCodeExpiresAt
    self.expiresAt = expiresAt
    self.tokenRequest = tokenRequest
    self.message = message
  }
}

