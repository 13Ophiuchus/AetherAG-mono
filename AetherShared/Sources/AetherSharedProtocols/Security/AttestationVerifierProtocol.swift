// AttestationVerifierProtocol.swift
// AetherAGMailServer

import Foundation

public protocol AttestationVerifierProtocol: Sendable {
    /// Verify a raw SE attestation string.
    /// Throw an `Abort(.unauthorized)` to reject the credential request.
    func verify(_ attestation: String?) async throws
}
