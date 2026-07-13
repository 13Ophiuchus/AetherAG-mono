//
//  VCJSONCanonicalizer.swift
//  AetherAGMailServer
//
//  Created by Nicholas Reich on 4/6/26.
//

//
//  VCJSONCanonicalizer.swift
//  AetherAGMailClient
//

import Foundation

public enum VCJSONCanonicalizer {
  public static func canonicalize<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}
