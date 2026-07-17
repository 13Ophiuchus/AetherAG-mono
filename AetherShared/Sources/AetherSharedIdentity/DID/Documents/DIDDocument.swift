//
//  DIDDocument.swift
//  AetherAGMailShared
//
//  Canonical DID domain models and service.
//

import Foundation

#if canImport(Vapor)
  import Vapor
#endif

public struct DIDDocument: Codable, Sendable {
  public var context: [String]
  public var id: String
  public var verificationMethod: [VerificationMethod]
  public var authentication: [String]
  public var assertionMethod: [String]?
  public var keyAgreement: [String]?
  public var service: [DIDService]?

  public enum CodingKeys: String, CodingKey {
    case context = "@context"
    case id
    case verificationMethod
    case authentication
    case assertionMethod
    case keyAgreement
    case service
  }

  public init(
    context: [String] = ["https://www.w3.org/ns/did/v1"],
    id: String,
    verificationMethod: [VerificationMethod],
    authentication: [String],
    assertionMethod: [String]? = nil,
    keyAgreement: [String]? = nil,
    service: [DIDService]? = nil
  ) {
    precondition(!context.isEmpty, "DIDDocument.context must not be empty")
    precondition(!id.isEmpty, "DIDDocument.id must not be empty")
    precondition(!verificationMethod.isEmpty, "DIDDocument.verificationMethod must not be empty")
    precondition(!authentication.isEmpty, "DIDDocument.authentication must not be empty")

    self.context = context
    self.id = id
    self.verificationMethod = verificationMethod
    self.authentication = authentication
    self.assertionMethod = assertionMethod
    self.keyAgreement = keyAgreement
    self.service = service
  }
}
