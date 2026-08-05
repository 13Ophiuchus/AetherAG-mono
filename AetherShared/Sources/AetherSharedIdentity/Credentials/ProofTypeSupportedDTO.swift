//
//  ProofTypeSupportedDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/19/26.
//

import Foundation

public struct ProofTypeSupportedDTO: Codable, Equatable, Hashable, Sendable {
  public let proofSigningAlgValuesSupported: [String]

  public init(proofSigningAlgValuesSupported: [String]) {
    self.proofSigningAlgValuesSupported = proofSigningAlgValuesSupported
  }

  public enum CodingKeys: String, CodingKey {
    case proofSigningAlgValuesSupported = "proof_signing_alg_values_supported"
  }
}
