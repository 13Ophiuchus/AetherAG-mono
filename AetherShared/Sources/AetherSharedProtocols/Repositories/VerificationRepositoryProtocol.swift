//
//  VerificationRepositoryProtocol.swift
//  AetherAG
//
//  Created by Nicholas Reich on 5/6/26.
//


import Foundation
import AetherSharedIdentity

protocol VerificationRepositoryProtocol: Sendable {
    func create(_ record: VerificationRequestRecord) async throws -> VerificationRequestRecord
    func find(id: UUID) async throws -> VerificationRequestRecord?
    func updateStatus(id: UUID, status: VerificationStatus) async throws
}
