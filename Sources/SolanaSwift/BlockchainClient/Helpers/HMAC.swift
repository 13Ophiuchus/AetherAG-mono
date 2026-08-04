import Crypto
import Foundation

func hmac(hmacAlgorithm: HMACAlgorithm, message: Data, key: Data) -> Data? {
    let symmetricKey = SymmetricKey(data: key)
    switch hmacAlgorithm {
    case .SHA256:
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey)
        return Data(mac)
    case .SHA384:
        let mac = HMAC<SHA384>.authenticationCode(for: message, using: symmetricKey)
        return Data(mac)
    case .SHA512:
        let mac = HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey)
        return Data(mac)
    }
}

func hmacSha512(message: Data, key: Data) -> Data? {
    return hmac(hmacAlgorithm: .SHA512, message: message, key: key)
}

enum HMACAlgorithm {
    case SHA256, SHA384, SHA512
}
