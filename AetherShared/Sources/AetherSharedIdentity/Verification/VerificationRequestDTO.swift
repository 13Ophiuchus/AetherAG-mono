//
//  VerificationRequestDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct VerificationRequestDTO: Codable, Equatable, Sendable {
  public let verifierDID: String
  public let subjectDID: String
  public let challenge: String
  public let domain: String
  public let requiredClaims: [String]

  public init(
    verifierDID: String,
    subjectDID: String,
    challenge: String,
    domain: String,
    requiredClaims: [String]
  ) {
    self.verifierDID = verifierDID
    self.subjectDID = subjectDID
    self.challenge = challenge
    self.domain = domain
    self.requiredClaims = requiredClaims
  }
}
