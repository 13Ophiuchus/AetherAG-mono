//
//  IssuanceAccessTokenClaimsDTO.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/17/26.
//

import Foundation

public struct IssuanceAccessTokenClaimsDTO: Codable, Equatable, Hashable, Sendable {
  public let subject: String
  public let issuer: String
  public let audience: [String]
  public let expiration: Date
  public let notBefore: Date?

  public init(
    subject: String,
    issuer: String,
    audience: [String],
    expiration: Date,
    notBefore: Date? = nil
  ) {
    self.subject = subject
    self.issuer = issuer
    self.audience = audience
    self.expiration = expiration
    self.notBefore = notBefore
  }

  public enum CodingKeys: String, CodingKey {
    case subject = "sub"
    case issuer = "iss"
    case audience = "aud"
    case expiration = "exp"
    case notBefore = "nbf"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.subject = try container.decode(String.self, forKey: .subject)
    self.issuer = try container.decode(String.self, forKey: .issuer)

    if let audienceArray = try container.decodeIfPresent([String].self, forKey: .audience) {
      self.audience = audienceArray
    } else if let singleAudience = try container.decodeIfPresent(String.self, forKey: .audience) {
      self.audience = [singleAudience]
    } else {
      self.audience = []
    }

    let expirationTimestamp = try container.decode(TimeInterval.self, forKey: .expiration)
    self.expiration = Date(timeIntervalSince1970: expirationTimestamp)

    if let notBeforeTimestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .notBefore)
    {
      self.notBefore = Date(timeIntervalSince1970: notBeforeTimestamp)
    } else {
      self.notBefore = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(subject, forKey: .subject)
    try container.encode(issuer, forKey: .issuer)

    if audience.count == 1, let first = audience.first {
      try container.encode(first, forKey: .audience)
    } else {
      try container.encode(audience, forKey: .audience)
    }

    try container.encode(Int(expiration.timeIntervalSince1970), forKey: .expiration)

    if let notBefore {
      try container.encode(Int(notBefore.timeIntervalSince1970), forKey: .notBefore)
    }
  }
}
