//
//  DevSeedIssuanceSessionRequestDTO.swift
//  AetherAGMailShared
//

import Foundation

public struct DevSeedIssuanceSessionRequestDTO: Codable, Equatable, Sendable {
	public let preAuthorizedCode: String?
	public let subjectDID: String?
	public let subjectPublicJWK: [String: String]?
	public let email: String?
	public let flowAccount: String?

	public init(
		preAuthorizedCode: String? = nil,
		subjectDID: String? = nil,
		subjectPublicJWK: [String: String]? = nil,
		email: String? = nil,
		flowAccount: String? = nil
	) {
		self.preAuthorizedCode = preAuthorizedCode
		self.subjectDID = subjectDID
		self.subjectPublicJWK = subjectPublicJWK
		self.email = email
		self.flowAccount = flowAccount
	}
}
