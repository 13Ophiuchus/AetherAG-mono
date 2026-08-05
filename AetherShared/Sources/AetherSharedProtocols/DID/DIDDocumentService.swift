//
//  DIDDocumentService.swift
//  AetherShared
//
//  Migrated from AetherAGMailShared.
//
import Foundation
import AetherSharedIdentity

public struct DIDDocumentService: DIDDocumentMaking, Sendable {
  public init() {}

  public func makeDIDDocument(
    did: String,
    keyFragment: String,
    jwk: [String: String],
    inboxURL: String? = nil
  ) -> DIDDocument {
    precondition(!did.isEmpty, "DID must not be empty")
    precondition(!keyFragment.isEmpty, "Key fragment must not be empty")
    precondition(!jwk.isEmpty, "JWK must not be empty")

    let normalizedFragment =
      keyFragment.hasPrefix("#") ? String(keyFragment.dropFirst()) : keyFragment
    let keyID = "\(did)#\(normalizedFragment)"

    let verificationMethod = VerificationMethod(
      id: keyID,
      type: "JsonWebKey2020",
      controller: did,
      publicKeyJwk: jwk
    )

    let services: [DIDService]? = {
      guard let inboxURL, !inboxURL.isEmpty else { return nil }
      return [
        DIDService(
          id: "\(did)#aether-inbox",
          type: "AetherInboxService",
          serviceEndpoint: inboxURL
        )
      ]
    }()

    return DIDDocument(
      id: did,
      verificationMethod: [verificationMethod],
      authentication: [keyID],
      assertionMethod: [keyID],
      keyAgreement: nil,
      service: services
    )
  }
}

extension DIDDocumentService: DIDDocumentServiceProtocol {}
