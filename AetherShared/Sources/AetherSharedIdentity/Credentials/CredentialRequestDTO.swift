//
//  CredentialRequestDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/20/26.
//

import Foundation

public struct CredentialRequestDTO: Codable, Equatable, Sendable {
  public let format: String
  public let proof: ProofDTO?
  public let credentialIdentifier: String?
  public let seAttestation: String?

  public init(
    format: String,
    proof: ProofDTO? = nil,
    credentialIdentifier: String? = nil,
    seAttestation: String? = nil
  ) {
    self.format = format
    self.proof = proof
    self.credentialIdentifier = credentialIdentifier
    self.seAttestation = seAttestation
  }

  public enum CodingKeys: String, CodingKey {
    case format
    case proof
    case credentialIdentifier = "credential_identifier"
    case seAttestation = "se_attestation"
  }
}
