//
//  BBSPlusSigningServiceProtocol.swift
//  AetherSharedProtocols
//

import Foundation
import AetherSharedIdentity

public protocol BBSPlusSigningServiceProtocol: Sendable {
  func sign(
    credential: VerifiableCredential,
    messages: [VCJSONCanonicalizer],
    privateKey: Data
  ) async throws -> VerifiableCredential
}
