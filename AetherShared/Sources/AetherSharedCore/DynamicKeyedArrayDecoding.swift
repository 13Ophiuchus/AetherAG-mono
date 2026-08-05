//
//  DynamicKeyedArrayDecoding.swift
//  AetherSharedCore
//
//  Generic helpers for decoding/encoding JSON objects whose keys are dynamic
//  (unknown at compile time) and whose values are arrays. Builds on
//  DynamicCodingKeys.swift. Foundation-only -- no Vapor/Flow/BigInt imports.
//

import Foundation

/// A single dynamic-key group: the original JSON key paired with its decoded array of elements.
public struct KeyedArrayGroup<Element>: Sendable where Element: Sendable {
  public let key: String
  public let values: [Element]

  public init(key: String, values: [Element]) {
    self.key = key
    self.values = values
  }
}

extension KeyedArrayGroup: Equatable where Element: Equatable {}
extension KeyedArrayGroup: Hashable where Element: Hashable {}

/// Decodes a JSON object at the root level whose keys are dynamic and whose
/// values are each a JSON array of `Element`.
///
/// Example JSON:
/// ```json
/// {
///   "2024-01-01": [{ "name": "A" }],
///   "2024-01-02": [{ "name": "B" }, { "name": "C" }]
/// }
/// ```
public struct DynamicKeyedArray<Element: Decodable & Sendable>: Decodable, Sendable {
  public let items: [KeyedArrayGroup<Element>]

  public init(items: [KeyedArrayGroup<Element>]) {
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

    var groups: [KeyedArrayGroup<Element>] = []
    groups.reserveCapacity(container.allKeys.count)

    for key in container.allKeys {
      let values = try container.decode([Element].self, forKey: key)
      groups.append(KeyedArrayGroup(key: key.stringValue, values: values))
    }

    self.items = groups
  }
}

extension DynamicKeyedArray: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKeys.self)
    for group in items {
      try container.encode(group.values, forKey: DynamicCodingKeys(group.key))
    }
  }
}

extension KeyedDecodingContainer where Key == DynamicCodingKeys {
  /// Decodes a nested dynamic-key object (whose values are arrays of `Element`)
  /// located at `key` within this container, flattening it into `[KeyedArrayGroup<Element>]`.
  ///
  /// Use this when the dynamic-key object is nested under a known key rather than at the JSON root.
  public func decodeDynamicKeyedArray<Element: Decodable>(
    ofElement elementType: Element.Type,
    forKey key: DynamicCodingKeys
  ) throws -> [KeyedArrayGroup<Element>] {
    let nested = try self.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key)

    var groups: [KeyedArrayGroup<Element>] = []
    groups.reserveCapacity(nested.allKeys.count)

    for nestedKey in nested.allKeys {
      let values = try nested.decode([Element].self, forKey: nestedKey)
      groups.append(KeyedArrayGroup(key: nestedKey.stringValue, values: values))
    }

    return groups
  }
}

extension KeyedDecodingContainer {
  /// Decodes a nested dynamic-key object (whose values are arrays of `Element`)
  /// located at `key` within a container keyed by this type's own `Key` type,
  /// flattening it into `[KeyedArrayGroup<Element>]`.
  public func decodeDynamicKeyedArray<Element: Decodable>(
    ofElement elementType: Element.Type,
    forKey key: Key
  ) throws -> [KeyedArrayGroup<Element>] {
    let nested = try self.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key)

    var groups: [KeyedArrayGroup<Element>] = []
    groups.reserveCapacity(nested.allKeys.count)

    for nestedKey in nested.allKeys {
      let values = try nested.decode([Element].self, forKey: nestedKey)
      groups.append(KeyedArrayGroup(key: nestedKey.stringValue, values: values))
    }

    return groups
  }
}
