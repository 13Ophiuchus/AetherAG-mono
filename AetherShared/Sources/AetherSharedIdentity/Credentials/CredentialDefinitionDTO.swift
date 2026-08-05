//
//  CredentialDefinitionDTO.swift
//  AetherAGMailServer
//
//  Created by Nicholas Reich on 4/13/26.
//
import Foundation

public struct CredentialDefinitionDTO: Codable, Equatable, Hashable, Sendable {
  public let type: [String]

  public init(type: [String]) {
    self.type = type
  }
}
