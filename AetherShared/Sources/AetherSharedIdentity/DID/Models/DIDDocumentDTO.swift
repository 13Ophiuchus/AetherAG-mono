//  DIDDocumentDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/16/26.
//

import Foundation

public struct DIDDocumentDTO: Codable, Equatable, Sendable {
  public let id: String
  public let verificationMethod: [DIDVerificationMethodDTO]
  public let authentication: [String]
  public let assertionMethod: [String]

  public init(
    id: String,
    verificationMethod: [DIDVerificationMethodDTO],
    authentication: [String],
    assertionMethod: [String]
  ) {
    self.id = id
    self.verificationMethod = verificationMethod
    self.authentication = authentication
    self.assertionMethod = assertionMethod
  }
}
