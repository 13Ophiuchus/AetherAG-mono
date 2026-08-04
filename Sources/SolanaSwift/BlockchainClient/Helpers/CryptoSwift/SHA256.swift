import Crypto
import Foundation

public func sha256(data: Data) -> Data {
    let digest = SHA256.hash(data: data)
    return Data(digest)
}
