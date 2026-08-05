//
//  CredentialDisplayDTO.swift
//  AetherAGMailServer
//
//  Created by Nicholas Reich on 4/13/26.
//
import Foundation

public struct CredentialDisplayDTO: Codable, Equatable, Hashable, Sendable {
  public let name: String
  public let locale: String?

  public init(
    name: String,
    locale: String? = nil
  ) {
    self.name = name
    self.locale = locale
  }
}
