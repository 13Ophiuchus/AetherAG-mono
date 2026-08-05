//
//  DIDVerificationMethodDTO.swift
//  AetherAGMailServer
//
//  Created by Nicholas Reich on 4/15/26.
//

import Foundation

public struct DIDVerificationMethodDTO: Codable, Equatable, Sendable {
  public let id: String
  public let type: String
  public let controller: String
  public let publicKeyJwk: [String: String]

  public init(
    id: String,
    type: String,
    controller: String,
    publicKeyJwk: [String: String]
  ) {
    self.id = id
    self.type = type
    self.controller = controller
    self.publicKeyJwk = publicKeyJwk
  }

  public enum CodingKeys: String, CodingKey {
    case id
    case type
    case controller
    case publicKeyJwk = "publicKeyJwk"
  }
}
