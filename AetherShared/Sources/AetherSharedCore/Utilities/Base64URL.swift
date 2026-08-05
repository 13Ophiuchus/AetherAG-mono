import Foundation

public enum Base64URL {
  public static func encode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  public static func decode(_ string: String) -> Data? {
    var decodedString =
      string
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let pad = 4 - (decodedString.count % 4)
    if pad < 4 { decodedString += String(repeating: "=", count: pad) }
    return Data(base64Encoded: decodedString)
  }
}
