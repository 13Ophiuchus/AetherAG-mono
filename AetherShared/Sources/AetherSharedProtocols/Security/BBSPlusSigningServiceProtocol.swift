//
//  BBSPlusSigningServiceProtocol.swift
//  AetherSharedProtocols
//

import AetherSharedIdentity
import Foundation

/// Service that applies a BBS+ signature to a VerifiableCredential.
/// Each canonicalized claim is passed as a discrete message so that
/// selective-disclosure proofs can reveal a subset without exposing all.
public protocol BBSPlusSigningServiceProtocol: Sendable {
    func sign(
        credential: VerifiableCredential,
        messages: [VCJSONCanonicalizer],
        privateKey: Data
    ) async throws -> VerifiableCredential
}
