//
//  VerificationStatus.swift
//  AetherAG.mail
//
//  Created by Nicholas Reich on 4/16/26.
//

// MARK: - Sources/App/Domain/Verification/VerificationModels.swift

import Foundation

public enum VerificationStatus: String, Sendable, Codable {
  case pending
  case approved
  case rejected
}

public struct VerificationRecord: Sendable, Codable, Equatable {
  public let id: UUID
  public let userID: UUID
  public let challenge: String
  public let domain: String
  public let createdAt: Date
  public let updatedAt: Date
  public let status: VerificationStatus

  public init(
    id: UUID,
    userID: UUID,
    challenge: String,
    domain: String,
    createdAt: Date,
    updatedAt: Date,
    status: VerificationStatus
  ) {
    self.id = id
    self.userID = userID
    self.challenge = challenge
    self.domain = domain
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.status = status
  }
}

public struct VerificationCreateRequest: Sendable, Codable, Equatable {
  public let userID: UUID
  public let challenge: String
  public let domain: String

  public init(userID: UUID, challenge: String, domain: String) {
    self.userID = userID
    self.challenge = challenge
    self.domain = domain
  }
}

public struct VerificationSubmissionRequest: Sendable, Codable, Equatable {
  public let vpToken: String
  public let presentationSubmission: PresentationSubmission

  enum CodingKeys: String, CodingKey {
    case vpToken = "vp_token"
    case presentationSubmission = "presentation_submission"
  }

  public init(vpToken: String, presentationSubmission: PresentationSubmission) {
    self.vpToken = vpToken
    self.presentationSubmission = presentationSubmission
  }
}

public struct VerificationDecision: Sendable, Codable, Equatable {
  public let verificationID: UUID
  public let status: VerificationStatus
  public let reason: String?

  public init(verificationID: UUID, status: VerificationStatus, reason: String?) {
    self.verificationID = verificationID
    self.status = status
    self.reason = reason
  }
}
