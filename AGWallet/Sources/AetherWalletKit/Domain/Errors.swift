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
        case .networkFailure(let message):
            return "Network failure: \(message)"
        case .unknownChain(let chain):
            return "Unknown chain: \(chain)"
        case .invalidAddress(let address):
            return "Invalid address: \(address)"
        case .invalidAmount(let amount):
            return "Invalid amount: \(amount)"
        case .keyGenerationFailed(let message):
            return "Key generation failed: \(message)"
        case .keyDerivationFailed(let message):
            return "Key derivation failed: \(message)"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        case .transactionBuildingFailed(let message):
            return "Transaction building failed: \(message)"
        case .transactionBroadcastFailed(let message):
            return "Transaction broadcast failed: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .secureEnclaveError(let message):
            return "Secure Enclave error: \(message)"
        case .mnemonicGenerationFailed(let message):
            return "Mnemonic generation failed: \(message)"
        case .chainConfigurationError(let message):
            return "Chain configuration error: \(message)"
        case .rpcError(let message):
            return "RPC error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        case .deserializationError(let message):
            return "Deserialization error: \(message)"
        case .unsupportedOperation(let message):
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