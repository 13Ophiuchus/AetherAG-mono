//
//  DIDDocument.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/27/26.
//
import AetherSharedIdentity

extension DIDDocument {
  public static func testDocument(
    did: String = "did:aether:test-user",
    inboxURL: String? = "https://example.com/inbox/did:aether:test-user"
  ) -> DIDDocument {
    let keyID = "\(did)#key-1"

    let verificationMethod = VerificationMethod(
      id: keyID,
      type: "JsonWebKey2020",
      controller: did,
      publicKeyJwk: [
        "kty": "EC",
        "crv": "P-256",
        "x": "test-x-coordinate",
        "y": "test-y-coordinate",
      ]
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
