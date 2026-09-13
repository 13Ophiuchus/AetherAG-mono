import Foundation

public enum WalletError: Error, LocalizedError, Sendable {
    case insufficientFunds
    case networkFailure(String)
    case unknownChain(String)
    case invalidAddress(String)
    case invalidAmount(String)
    case keyGenerationFailed(String)
    case keyDerivationFailed(String)
    case signingFailed(String)
    case transactionBuildingFailed(String)
    case transactionBroadcastFailed(String)
    case keychainError(String)
    case secureEnclaveError(String)
    case mnemonicGenerationFailed(String)
    case chainConfigurationError(String)
    case rpcError(String)
    case invalidResponse(String)
    case serializationError(String)
    case deserializationError(String)
    case unsupportedOperation(String)

    public var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient funds for this transaction"
        case let .networkFailure(message):
            return "Network failure: \(message)"
        case let .unknownChain(chain):
            return "Unknown chain: \(chain)"
        case let .invalidAddress(address):
            return "Invalid address: \(address)"
        case let .invalidAmount(amount):
            return "Invalid amount: \(amount)"
        case let .keyGenerationFailed(message):
            return "Key generation failed: \(message)"
        case let .keyDerivationFailed(message):
            return "Key derivation failed: \(message)"
        case let .signingFailed(message):
            return "Signing failed: \(message)"
        case let .transactionBuildingFailed(message):
            return "Transaction building failed: \(message)"
        case let .transactionBroadcastFailed(message):
            return "Transaction broadcast failed: \(message)"
        case let .keychainError(message):
            return "Keychain error: \(message)"
        case let .secureEnclaveError(message):
            return "Secure Enclave error: \(message)"
        case let .mnemonicGenerationFailed(message):
            return "Mnemonic generation failed: \(message)"
        case let .chainConfigurationError(message):
            return "Chain configuration error: \(message)"
        case let .rpcError(message):
            return "RPC error: \(message)"
        case let .invalidResponse(message):
            return "Invalid response: \(message)"
        case let .serializationError(message):
            return "Serialization error: \(message)"
        case let .deserializationError(message):
            return "Deserialization error: \(message)"
        case let .unsupportedOperation(message):
            return "Unsupported operation: \(message)"
        }
    }
}

public enum KeyDerivationError: Error, LocalizedError, Sendable {
    case invalidMnemonic
    case invalidDerivationPath
    case unsupportedCurve
    case keyNotFound
    case invalidSeed

    public var errorDescription: String? {
        switch self {
        case .invalidMnemonic:
            return "Invalid mnemonic phrase"
        case .invalidDerivationPath:
            return "Invalid derivation path"
        case .unsupportedCurve:
            return "Unsupported elliptic curve"
        case .keyNotFound:
            return "Key not found"
        case .invalidSeed:
            return "Invalid seed"
        }
    }
}
