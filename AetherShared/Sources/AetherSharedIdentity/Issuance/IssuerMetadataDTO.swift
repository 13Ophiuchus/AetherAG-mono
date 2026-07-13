//
//  IssuerMetadataDTO.swift
//  AetherSharedIdentity
//

import Foundation

public struct IssuerMetadataDTO: Codable, Equatable, Sendable {
  public let credentialIssuer: String
  public let authorizationServers: [String]
  public let credentialEndpoint: String
  public let tokenEndpoint: String
  public let credentialConfigurationsSupported: [String: CredentialConfigurationSupportedDTO]

  public init(
    credentialIssuer: String,
    authorizationServers: [String],
    credentialEndpoint: String,
    tokenEndpoint: String,
    credentialConfigurationsSupported: [String: CredentialConfigurationSupportedDTO]
  ) {
    self.credentialIssuer = credentialIssuer
    self.authorizationServers = authorizationServers
    self.credentialEndpoint = credentialEndpoint
    self.tokenEndpoint = tokenEndpoint
    self.credentialConfigurationsSupported = credentialConfigurationsSupported
  }

  public enum CodingKeys: String, CodingKey {
    case credentialIssuer = "credential_issuer"
    case authorizationServers = "authorization_servers"
    case credentialEndpoint = "credential_endpoint"
    case tokenEndpoint = "token_endpoint"
    case credentialConfigurationsSupported = "credential_configurations_supported"
  }
}
