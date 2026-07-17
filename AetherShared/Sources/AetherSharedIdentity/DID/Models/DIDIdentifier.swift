//
//  DIDIdentifier.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/14/26.
//

import Foundation

/// Strongly-typed wrapper for a Decentralized Identifier (DID or DID URL).
///
/// Examples:
/// - "did:web:example.com"
/// - "did:key:z6Mkq...xyz"
/// - "did:example:abc123#key-1"
public struct DIDIdentifier: Hashable, Sendable, Codable, CustomStringConvertible {

  // MARK: - Stored Properties

  /// Canonical string value of the DID or DID URL.
  public let rawValue: String

  // MARK: - Derived Properties

  /// DID method name, e.g. "web", "key", "example".
  public var method: String {
    let parts = rawValue.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count >= 2 else { return "" }
    return String(parts[1])
  }

  /// Method-specific-id portion, excluding any fragment.
  public var methodSpecificId: String {
    let parts = rawValue.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3 else { return "" }
    return String(parts[2])
  }

  /// Optional fragment component for DID URLs, e.g. "#key-1".
  public var fragment: String? {
    guard let hashIndex = rawValue.firstIndex(of: "#") else { return nil }
    let start = rawValue.index(after: hashIndex)
    guard start < rawValue.endIndex else { return nil }
    return String(rawValue[start...])
  }

  /// Base DID without the fragment.
  public var baseDID: DIDIdentifier {
    guard let hashIndex = rawValue.firstIndex(of: "#") else { return self }
    let base = String(rawValue[..<hashIndex])
    return DIDIdentifier(unsafe: base)
  }

  public var description: String { rawValue }

  // MARK: - Initializers

  /// Validating initializer.
  public init?(_ rawValue: String) {
    guard Self.isValidDID(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  /// Internal initializer that skips validation.
  init(unsafe rawValue: String) {
    self.rawValue = rawValue
  }

  // MARK: - Validation

  /// Validates a DID string according to DID Core syntax (approximate).
  public static func isValidDID(_ value: String) -> Bool {
    guard value.hasPrefix("did:") else { return false }

    let base =
      value
      .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
      .first
      .map(String.init) ?? value

    let parts = base.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3 else { return false }

    let method = String(parts[1])
    let methodSpecificID = String(parts[2])

    guard !method.isEmpty, !methodSpecificID.isEmpty else { return false }

    let methodRegex = "^[a-z0-9]+$"
    guard NSPredicate(format: "SELF MATCHES %@", methodRegex).evaluate(with: method) else {
      return false
    }

    let methodSpecificIDRegex = "^[A-Za-z0-9._:%-]+$"
    guard
      NSPredicate(format: "SELF MATCHES %@", methodSpecificIDRegex).evaluate(with: methodSpecificID)
    else {
      return false
    }

    return true
  }

  // MARK: - Convenience Constructors

  public static func web(domain: String, path: String? = nil) -> DIDIdentifier? {
    guard !domain.isEmpty else { return nil }

    let encodedDomain =
      domain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? domain

    if let path, !path.isEmpty {
      let normalizedPath =
        path
        .split(separator: "/", omittingEmptySubsequences: true)
        .map(String.init)
        .joined(separator: ":")
      return DIDIdentifier("did:web:\(encodedDomain):\(normalizedPath)")
    }

    return DIDIdentifier("did:web:\(encodedDomain)")
  }

  public static func key(multibaseKey: String) -> DIDIdentifier? {
    guard multibaseKey.hasPrefix("z"), multibaseKey.count > 1 else { return nil }
    return DIDIdentifier("did:key:\(multibaseKey)")
  }

  // MARK: - Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)

    guard let did = DIDIdentifier(value) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid DID identifier: \(value)"
      )
    }

    self = did
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
