//
//  VerificationResultDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct VerificationResultDTO: Codable, Equatable, Sendable {
  public let requestID: String
  public let verified: Bool
  public let message: String?

  public init(
    requestID: String,
    verified: Bool,
    message: String? = nil
  ) {
    self.requestID = requestID
    self.verified = verified
    self.message = message
  }
}
