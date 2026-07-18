//
//  DIDResolving.swift
//  AetherSharedProtocols
//

import Foundation
import AetherSharedIdentity

public protocol DIDResolving: Sendable {
  func resolve(_ did: String) async throws -> DIDDocument
}
