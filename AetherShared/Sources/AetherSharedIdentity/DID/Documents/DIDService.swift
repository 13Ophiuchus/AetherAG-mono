//
//  DIDService.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/27/26.
//
import Foundation

public struct DIDService: Codable, Sendable {
  public let id: String
  public let type: String
  public let serviceEndpoint: String

  public init(
    id: String,
    type: String,
    serviceEndpoint: String
  ) {
    precondition(!id.isEmpty, "DIDService.id must not be empty")
    precondition(!type.isEmpty, "DIDService.type must not be empty")
    precondition(!serviceEndpoint.isEmpty, "DIDService.serviceEndpoint must not be empty")

    self.id = id
    self.type = type
    self.serviceEndpoint = serviceEndpoint
  }
}
