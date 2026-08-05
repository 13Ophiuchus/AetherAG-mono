//
//  VerificationMethod.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/13/26.
//
import CoreFoundation

public struct VerificationMethod: Codable, Sendable {
  public var id: String
  public var type: String
  public var controller: String
  public var publicKeyJwk: [String: String]

  public init(
    id: String,
    type: String,
    controller: String,
    publicKeyJwk: [String: String]
  ) {
    precondition(!id.isEmpty, "VerificationMethod.id must not be empty")
    precondition(!type.isEmpty, "VerificationMethod.type must not be empty")
    precondition(!controller.isEmpty, "VerificationMethod.controller must not be empty")
    precondition(!publicKeyJwk.isEmpty, "VerificationMethod.publicKeyJwk must not be empty")

    self.id = id
    self.type = type
    self.controller = controller
    self.publicKeyJwk = publicKeyJwk
  }
}
