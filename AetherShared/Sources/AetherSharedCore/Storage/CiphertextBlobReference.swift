//
//  CiphertextBlobReference.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/25/26.
//

import Foundation

public struct CiphertextBlobReference: Codable, Sendable, Hashable, Identifiable {
  public let id: UUID
  public let bucket: String
  public let key: String
  public let contentType: String
  public let createdAt: Date
  public let createdByDID: String
  public let encryptionContext: [String: String]
  public let sessionID: UUID?

  public init(
    id: UUID = UUID(),
    bucket: String,
    key: String,
    contentType: String,
    createdAt: Date = .now,
    createdByDID: String,
    encryptionContext: [String: String] = [:],
    sessionID: UUID? = nil
  ) {
    self.id = id
    self.bucket = bucket
    self.key = key
    self.contentType = contentType
    self.createdAt = createdAt
    self.createdByDID = createdByDID
    self.encryptionContext = encryptionContext
    self.sessionID = sessionID
  }
}
