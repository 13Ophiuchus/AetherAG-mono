//
//  DIDResolving.swift
//  AetherSharedProtocols
//

import AetherSharedIdentity
import Foundation

public protocol DIDResolving: Sendable {
    func resolve(_ did: String) async throws -> DIDDocument
}
