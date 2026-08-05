//
//  String+JSON.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/22/26.
//

import Foundation

public enum StringJSONError: Error, LocalizedError, Sendable {
  case invalidUTF8
  case notJSONObject
  case notJSONArray
  case serializationFailed(Error)

  public var errorDescription: String? {
    switch self {
    case .invalidUTF8:
      return "String could not be converted to UTF-8 data."
    case .notJSONObject:
      return "JSON was valid, but the top-level value was not an object."
    case .notJSONArray:
      return "JSON was valid, but the top-level value was not an array."
    case .serializationFailed(let error):
      return "Failed to parse JSON: \(error.localizedDescription)"
    }
  }
}

extension String {
  public func toJSONData() throws -> Data {
    guard let data = data(using: .utf8) else {
      throw StringJSONError.invalidUTF8
    }
    return data
  }

  public func toJSONDictionary() throws -> [String: Any] {
    let data = try toJSONData()

    do {
      let object = try JSONSerialization.jsonObject(with: data)
      guard let dictionary = object as? [String: Any] else {
        throw StringJSONError.notJSONObject
      }
      return dictionary
    } catch let error as StringJSONError {
      throw error
    } catch {
      throw StringJSONError.serializationFailed(error)
    }
  }

  public func toJSONArray() throws -> [Any] {
    let data = try toJSONData()

    do {
      let object = try JSONSerialization.jsonObject(with: data)
      guard let array = object as? [Any] else {
        throw StringJSONError.notJSONArray
      }
      return array
    } catch let error as StringJSONError {
      throw error
    } catch {
      throw StringJSONError.serializationFailed(error)
    }
  }

  public func toJSONDictionaryIfValid() -> [String: Any]? {
    try? toJSONDictionary()
  }

  public func toJSONArrayIfValid() -> [Any]? {
    try? toJSONArray()
  }

  public func toJSONDataIfValid() -> Data? {
    try? toJSONData()
  }
}
