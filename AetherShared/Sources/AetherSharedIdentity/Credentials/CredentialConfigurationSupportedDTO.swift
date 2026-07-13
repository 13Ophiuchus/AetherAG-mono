import Foundation

public struct CredentialConfigurationSupportedDTO: Codable, Equatable, Sendable {
  public let format: String
  public let scope: String?
  public let cryptographicBindingMethodsSupported: [String]?
  public let credentialSigningAlgValuesSupported: [String]?
  public let proofTypesSupported: [String: ProofTypeSupportedDTO]?
  public let display: [CredentialConfigurationDisplayDTO]?
  public let credentialDefinition: CredentialDefinitionDTO?

  public init(
    format: String,
    scope: String? = nil,
    cryptographicBindingMethodsSupported: [String]? = nil,
    credentialSigningAlgValuesSupported: [String]? = nil,
    proofTypesSupported: [String: ProofTypeSupportedDTO]? = nil,
    display: [CredentialConfigurationDisplayDTO]? = nil,
    credentialDefinition: CredentialDefinitionDTO? = nil
  ) {
    self.format = format
    self.scope = scope
    self.cryptographicBindingMethodsSupported = cryptographicBindingMethodsSupported
    self.credentialSigningAlgValuesSupported = credentialSigningAlgValuesSupported
    self.proofTypesSupported = proofTypesSupported
    self.display = display
    self.credentialDefinition = credentialDefinition
  }

  public enum CodingKeys: String, CodingKey {
    case format
    case scope
    case cryptographicBindingMethodsSupported = "cryptographic_binding_methods_supported"
    case credentialSigningAlgValuesSupported = "credential_signing_alg_values_supported"
    case proofTypesSupported = "proof_types_supported"
    case display
    case credentialDefinition = "credential_definition"
  }
}
