import Foundation

struct DIDKeyFormatter {
  static func formatEd25519Key(publicKey: Data) -> String {
    // Convert Ed25519 public key to did:key format
    let multicodecPrefix = Data([0xed, 0x01])  // Ed25519 multicodec prefix
    let keyData = multicodecPrefix + publicKey
    let base58Key = Base58Encoder.encode(keyData)
    return "did:key:z\(base58Key)"
  }

  static func formatWebDID(domain: String, path: String = "") -> String {
    let encodedDomain =
      domain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? domain
    let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path

    if path.isEmpty {
      return "did:web:\(encodedDomain)"
    } else {
      return "did:web:\(encodedDomain):\(encodedPath)"
    }
  }

  static func extractKeyFromDIDKey(_ did: String) -> Data? {
    guard did.hasPrefix("did:key:z") else {
      return nil
    }

    let keyPart = String(did.dropFirst("did:key:z".count))
    guard let keyData = Base58Encoder.decode(keyPart) else {
      return nil
    }

    // Remove multicodec prefix
    guard keyData.count > 2 else {
      return nil
    }

    return keyData.dropFirst(2)
  }
}

struct Base58Encoder {
  private static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  static func encode(_ data: Data) -> String {
    var bytes = Array(data)
    var result = ""
    var zeros = 0

    // Count leading zeros
    while zeros < bytes.count && bytes[zeros] == 0 {
      zeros += 1
    }

    // Convert to base58
    bytes.removeFirst(zeros)

    while !bytes.isEmpty {
      var carry = 0
      for i in 0..<bytes.count {
        carry = carry * 256 + Int(bytes[i])
        bytes[i] = UInt8(carry / 58)
        carry %= 58
      }

      result = String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: carry)]) + result

      // Remove leading zeros
      while !bytes.isEmpty && bytes[0] == 0 {
        bytes.removeFirst()
      }
    }

    // Add leading 1s for original leading zeros
    for _ in 0..<zeros {
      result = "1" + result
    }

    return result
  }

  static func decode(_ string: String) -> Data? {
    var result = [UInt8](repeating: 0, count: string.count * 2)
    var resultLength = 0
    var zeros = 0

    // Count leading zeros
    for char in string {
      if char == "1" {
        zeros += 1
      } else {
        break
      }
    }

    // Convert from base58
    for char in string.dropFirst(zeros) {
      guard let index = alphabet.firstIndex(of: char) else {
        return nil
      }

      let charValue = alphabet.distance(from: alphabet.startIndex, to: index)

      var carry = charValue
      for i in 0..<resultLength {
        carry += 58 * Int(result[i])
        result[i] = UInt8(carry % 256)
        carry /= 256
      }

      while carry > 0 {
        if resultLength >= result.count {
          result.append(0)
        }
        result[resultLength] = UInt8(carry % 256)
        resultLength += 1
        carry /= 256
      }
    }

    // Add leading zeros
    result.insert(contentsOf: [UInt8](repeating: 0, count: zeros), at: 0)
    resultLength += zeros

    return Data(result[0..<resultLength])
  }
}
