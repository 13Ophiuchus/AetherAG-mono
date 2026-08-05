//
//  ProofDTO.swift
//  AetherAGMailServer
//
//  Created by Nicholas Reich on 4/13/26.
//

import Foundation

public struct ProofDTO: Codable, Equatable, Sendable {
  public let proofType: String
  public let jwt: String?

  public init(
    proofType: String,
    jwt: String? = nil
  ) {
    self.proofType = proofType
    self.jwt = jwt
  }

  public enum CodingKeys: String, CodingKey {
    case proofType = "proof_type"
    case jwt
  }
}
