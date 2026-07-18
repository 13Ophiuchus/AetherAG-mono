//
//  BBSPlusSigningSuite.swift
//  AetherSharedProtocols
//

import Foundation

public protocol BBSPlusSigningSuite: Sendable {
  func sign(
    messages: [Data],
    privateKey: Data
  ) async throws -> String
}
