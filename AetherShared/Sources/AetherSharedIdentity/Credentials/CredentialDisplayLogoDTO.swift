//
//  CredentialDisplayLogoDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/19/26.
//

import Foundation

public struct CredentialDisplayLogoDTO: Codable, Equatable, Hashable, Sendable {
  public let uri: String?
  public let altText: String?

  public init(
    uri: String? = nil,
    altText: String? = nil
  ) {
    self.uri = uri
    self.altText = altText
  }

  public enum CodingKeys: String, CodingKey {
    case uri
    case altText = "alt_text"
  }
}
