//
//  VCJSONCanonicalizer.swift
//  AetherSharedIdentity
//

import Foundation

/// Wraps an Encodable value and produces its canonical JSON bytes
/// (sorted keys, no escaped slashes). Used as a message unit for
/// BBS+ signing so each canonicalized claim is a discrete Data message.
public struct VCJSONCanonicalizer: Sendable {
  private let _canonicalize: @Sendable () throws -> Data

  public init<T: Encodable & Sendable>(_ value: T) {
    self._canonicalize = {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
      return try encoder.encode(value)
    }
  }

  public func canonicalized() throws -> Data {
    try _canonicalize()
  }

  // Convenience static helper retained for call-sites that just need Data
  public static func canonicalize<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}
