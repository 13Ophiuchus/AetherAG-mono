//
//  VerificationStatusResponse.swift
//  AetherSharedIdentity
//

import Foundation

public struct VerificationStatusResponse: Codable, Equatable, Sendable {
  public let status: VerificationStatus

  public init(status: VerificationStatus) {
    self.status = status
  }
}
