//
//  CredentialConfigurationDisplayDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/19/26.
//

import Foundation

public struct CredentialConfigurationDisplayDTO: Codable, Equatable, Hashable, Sendable {
  public let name: String?
  public let locale: String?
  public let logo: CredentialDisplayLogoDTO?
  public let backgroundColor: String?
  public let textColor: String?

  public init(
    name: String? = nil,
    locale: String? = nil,
    logo: CredentialDisplayLogoDTO? = nil,
    backgroundColor: String? = nil,
    textColor: String? = nil
  ) {
    self.name = name
    self.locale = locale
    self.logo = logo
    self.backgroundColor = backgroundColor
    self.textColor = textColor
  }

  public enum CodingKeys: String, CodingKey {
    case name
    case locale
    case logo
    case backgroundColor = "background_color"
    case textColor = "text_color"
  }
}
