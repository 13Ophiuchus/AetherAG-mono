//
//  VerifiablePresentation.swift
//  AetherAGMailShared
//

import Foundation

public struct VerifiablePresentation: Codable, Sendable {
  public let context: String
  public let type: String
  public let verifiableCredential: VerifiableCredential
  public let proof: PresentationProof

  public init(
    context: String,
    type: String,
    verifiableCredential: VerifiableCredential,
    proof: PresentationProof
  ) {
    self.context = context
    self.type = type
    self.verifiableCredential = verifiableCredential
    self.proof = proof
  }

  enum CodingKeys: String, CodingKey {
    case context = "@context"
    case type
    case verifiableCredential = "verifiableCredential"
    case proof
  }
}

public struct PresentationProof: Codable, Sendable {
  public let type: String
  public let created: String
  public let proofPurpose: String
  public let verificationMethod: String
  public let challenge: String
  public let domain: String
  public let proofValue: String

  public init(
    type: String,
    created: String,
    proofPurpose: String,
    verificationMethod: String,
    challenge: String,
    domain: String,
    proofValue: String
  ) {
    self.type = type
    self.created = created
    self.proofPurpose = proofPurpose
    self.verificationMethod = verificationMethod
    self.challenge = challenge
    self.domain = domain
    self.proofValue = proofValue
  }

  enum CodingKeys: String, CodingKey {
    case type
    case created
    case proofPurpose = "proofPurpose"
    case verificationMethod = "verificationMethod"
    case challenge
    case domain
    case proofValue = "proofValue"
  }
}
