import Foundation

// MARK: - Domain Models

public enum ChainType: String, Codable, Sendable {
    case bitcoin
    case evm
    case solana
    case flow
}

public struct ChainConfig: Codable, Sendable, Equatable {
    public let chainId: String
    public let name: String
    public let type: ChainType
    public let rpcEndpoints: [URL]
    public let explorerUrl: URL?
    public let derivationPath: String
    public let nativeAssetSymbol: String
    public let customConfig: [String: String]?
    
    public init(
        chainId: String,
        name: String,
        type: ChainType,
        rpcEndpoints: [URL],
        explorerUrl: URL? = nil,
        derivationPath: String,
        nativeAssetSymbol: String,
        customConfig: [String: String]? = nil
    ) {
        self.chainId = chainId
        self.name = name
        self.type = type
        self.rpcEndpoints = rpcEndpoints
        self.explorerUrl = explorerUrl
        self.derivationPath = derivationPath
        self.nativeAssetSymbol = nativeAssetSymbol
        self.customConfig = customConfig
    }
}

public struct CryptoAsset: Codable, Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let balance: Double
    public let contractAddress: String?
    public let chainConfig: ChainConfig
    public let decimals: Int
    
    public init(
        name: String,
        symbol: String,
        balance: Double = 0.0,
        contractAddress: String? = nil,
        chainConfig: ChainConfig,
        decimals: Int = 18
    ) {
        self.name = name
        self.symbol = symbol
        self.balance = balance
        self.contractAddress = contractAddress
        self.chainConfig = chainConfig
        self.decimals = decimals
    }
}

public enum TransactionStatus: String, Codable, Sendable {
    case pending
    case confirmed
    case failed
    case unknown
}

public struct BitcoinTransaction: Codable, Sendable {
    public let txId: String
    public let inputs: [BitcoinInput]
    public let outputs: [BitcoinOutput]
    public let fee: Double
    public let blockHeight: Int?
    public let timestamp: Date
    
    public init(txId: String, inputs: [BitcoinInput], outputs: [BitcoinOutput], fee: Double, blockHeight: Int? = nil, timestamp: Date) {
        self.txId = txId
        self.inputs = inputs
        self.outputs = outputs
        self.fee = fee
        self.blockHeight = blockHeight
        self.timestamp = timestamp
    }
}

public struct BitcoinInput: Codable, Sendable {
    public let previousTxId: String
    public let outputIndex: Int
    public let value: Double
    public let address: String
    
    public init(previousTxId: String, outputIndex: Int, value: Double, address: String) {
        self.previousTxId = previousTxId
        self.outputIndex = outputIndex
        self.value = value
        self.address = address
    }
}

public struct BitcoinOutput: Codable, Sendable {
    public let value: Double
    public let address: String
    public let script: Data
    
    public init(value: Double, address: String, script: Data) {
        self.value = value
        self.address = address
        self.script = script
    }
}

public struct SolanaTransaction: Codable, Sendable {
    public let signature: String
    public let recentBlockhash: String
    public let instructions: [SolanaInstruction]
    public let fee: Double
    public let slot: UInt64?
    public let timestamp: Date
    
    public init(signature: String, recentBlockhash: String, instructions: [SolanaInstruction], fee: Double, slot: UInt64? = nil, timestamp: Date) {
        self.signature = signature
        self.recentBlockhash = recentBlockhash
        self.instructions = instructions
        self.fee = fee
        self.slot = slot
        self.timestamp = timestamp
    }
}

public struct SolanaInstruction: Codable, Sendable {
    public let programId: String
    public let accounts: [String]
    public let data: Data
    
    public init(programId: String, accounts: [String], data: Data) {
        self.programId = programId
        self.accounts = accounts
        self.data = data
    }
}

public struct EVMTransaction: Codable, Sendable {
    public let hash: String
    public let from: String
    public let to: String
    public let value: String
    public let gasPrice: String
    public let gasLimit: String
    public let nonce: Int
    public let chainId: Int
    public let blockNumber: String?
    public let timestamp: Date
    
    public init(hash: String, from: String, to: String, value: String, gasPrice: String, gasLimit: String, nonce: Int, chainId: Int, blockNumber: String? = nil, timestamp: Date) {
        self.hash = hash
        self.from = from
        self.to = to
        self.value = value
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.nonce = nonce
        self.chainId = chainId
        self.blockNumber = blockNumber
        self.timestamp = timestamp
    }
}

public struct FlowTransaction: Codable, Sendable {
    public let id: String
    public let script: String
    public let arguments: [FlowArgument]
    public let proposer: String
    public let authorizers: [String]
    public let payer: String
    public let gasLimit: Int
    public let status: FlowTransactionStatus
    public let timestamp: Date
    
    public init(id: String, script: String, arguments: [FlowArgument], proposer: String, authorizers: [String], payer: String, gasLimit: Int, status: FlowTransactionStatus, timestamp: Date) {
        self.id = id
        self.script = script
        self.arguments = arguments
        self.proposer = proposer
        self.authorizers = authorizers
        self.payer = payer
        self.gasLimit = gasLimit
        self.status = status
        self.timestamp = timestamp
    }
}

public struct FlowArgument: Codable, Sendable {
    public let type: String
    public let value: String
    
    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }
}

public enum FlowTransactionStatus: String, Codable, Sendable {
    case unknown
    case pending
    case finalized
    case executed
    case sealed
    case expired
}

public enum UnifiedTransaction: Codable, Sendable {
    case bitcoin(BitcoinTransaction)
    case solana(SolanaTransaction)
    case evm(EVMTransaction)
    case flow(FlowTransaction)
    
    public var id: String {
        switch self {
        case .bitcoin(let tx): return tx.txId
        case .solana(let tx): return tx.signature
        case .evm(let tx): return tx.hash
        case .flow(let tx): return tx.id
        }
    }
    
    public var status: TransactionStatus {
        switch self {
        case .bitcoin(let tx): return tx.blockHeight != nil ? .confirmed : .pending
        case .solana(let tx): return tx.slot != nil ? .confirmed : .pending
        case .evm(let tx): return tx.blockNumber != nil ? .confirmed : .pending
        case .flow(let tx):
            switch tx.status {
            case .pending: return .pending
            case .finalized, .executed, .sealed: return .confirmed
            case .expired: return .failed
            case .unknown: return .unknown
            }
        }
    }
    
    public var fromAddress: String {
        switch self {
        case .bitcoin(let tx):
            return tx.inputs.first?.address ?? ""
        case .solana(let tx):
            return tx.instructions.first?.accounts.first ?? ""
        case .evm(let tx):
            return tx.from
        case .flow(let tx):
            return tx.proposer
        }
    }
    
    public var toAddress: String {
        switch self {
        case .bitcoin(let tx):
            return tx.outputs.first?.address ?? ""
        case .solana(let tx):
            return tx.instructions.first?.accounts.last ?? ""
        case .evm(let tx):
            return tx.to
        case .flow(let tx):
            return tx.authorizers.first ?? ""
        }
    }
    
    public var value: Double {
        switch self {
        case .bitcoin(let tx):
            return tx.outputs.reduce(0) { $0 + $1.value }
        case .solana(let tx):
            return tx.fee // Simplified - in reality would parse instruction data
        case .evm(let tx):
            return Double(tx.value) ?? 0.0
        case .flow(let tx):
            return 0.0 // Would parse from arguments
        }
    }
    
    public var fee: Double {
        switch self {
        case .bitcoin(let tx): return tx.fee
        case .solana(let tx): return tx.fee
        case .evm(let tx):
            return (Double(tx.gasPrice) ?? 0.0) * (Double(tx.gasLimit) ?? 0.0)
        case .flow(let tx):
            return 0.0 // Would calculate based on gas
        }
    }
    
    public var date: Date {
        switch self {
        case .bitcoin(let tx): return tx.timestamp
        case .solana(let tx): return tx.timestamp
        case .evm(let tx): return tx.timestamp
        case .flow(let tx): return tx.timestamp
        }
    }
    
    public var description: String {
        switch self {
        case .bitcoin(let tx):
            return "Bitcoin transaction \(tx.txId) with \(tx.outputs.count) outputs"
        case .solana(let tx):
            return "Solana transaction \(tx.signature) with \(tx.instructions.count) instructions"
        case .evm(let tx):
            return "EVM transaction \(tx.hash) from \(tx.from) to \(tx.to)"
        case .flow(let tx):
            return "Flow transaction \(tx.id) with \(tx.authorizers.count) authorizers"
        }
    }
}

// MARK: - Error Types

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

// MARK: - Logger

public class Logger {
    public let label: String
    
    public init(label: String) {
        self.label = label
    }
    
    public func info(_ message: String) {
        osLog.info("\(message, privacy: .public)")
    }
    
    public func warning(_ message: String) {
        osLog.warning("\(message, privacy: .public)")
    }
    
    public func error(_ message: String) {
        osLog.error("\(message, privacy: .public)")
    }
    
    public func debug(_ message: String) {
        osLog.debug("\(message, privacy: .private)")
    }
}

// MARK: - WalletCore Actor

public actor WalletCore {
    private let keyManager: KeyManagerActor
    private let chainConfigService: ChainConfigurationService
    private let bitcoinModule: BitcoinModule?
    private let solanaModule: SolanaModule?
    private let evmModule: EVMModule?
    private let flowModule: FlowModule?
    private let logger = Logger(label: "AetherWalletKit.WalletCore")
    
    public init(
        keyManager: KeyManagerActor,
        chainConfigService: ChainConfigurationService,
        enableBitcoin: Bool = true,
        enableSolana: Bool = true,
        enableEVM: Bool = true,
        enableFlow: Bool = true
    ) {
        self.keyManager = keyManager
        self.chainConfigService = chainConfigService
        
        self.bitcoinModule = enableBitcoin ? BitcoinModule(keyManager: keyManager) : nil
        self.solanaModule = enableSolana ? SolanaModule(keyManager: keyManager) : nil
        self.evmModule = enableEVM ? EVMModule(keyManager: keyManager) : nil
        self.flowModule = enableFlow ? FlowModule(keyManager: keyManager) : nil
    }
    
    public func getBalance(for asset: CryptoAsset) async throws -> Double {
        logger.info("Getting balance for \(asset.symbol) on \(asset.chainConfig.name)")
        
        switch asset.chainConfig.type {
        case .bitcoin:
            guard let bitcoinModule = bitcoinModule else {
                throw WalletError.unsupportedOperation("Bitcoin module not enabled")
            }
            return try await bitcoinModule.getBalance(for: asset)
            
        case .solana:
            guard let solanaModule = solanaModule else {
                throw WalletError.unsupportedOperation("Solana module not enabled")
            }
            return try await solanaModule.getBalance(for: asset)
            
        case .evm:
            guard let evmModule = evmModule else {
                throw WalletError.unsupportedOperation("EVM module not enabled")
            }
            return try await evmModule.getBalance(for: asset)
            
        case .flow:
            guard let flowModule = flowModule else {
                throw WalletError.unsupportedOperation("Flow module not enabled")
            }
            return try await flowModule.getBalance(for: asset)
        }
    }
    
    public func send(
        amount: Double,
        to recipientAddress: String,
        for asset: CryptoAsset
    ) async throws -> UnifiedTransaction {
        logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")
        
        switch asset.chainConfig.type {
        case .bitcoin:
            guard let bitcoinModule = bitcoinModule else {
                throw WalletError.unsupportedOperation("Bitcoin module not enabled")
            }
            return try await bitcoinModule.send(amount: amount, to: recipientAddress, for: asset)
            
        case .solana:
            guard let solanaModule = solanaModule else {
                throw WalletError.unsupportedOperation("Solana module not enabled")
            }
            return try await solanaModule.send(amount: amount, to: recipientAddress, for: asset)
            
        case .evm:
            guard let evmModule = evmModule else {
                throw WalletError.unsupportedOperation("EVM module not enabled")
            }
            return try await evmModule.send(amount: amount, to: recipientAddress, for: asset)
            
        case .flow:
            guard let flowModule = flowModule else {
                throw WalletError.unsupportedOperation("Flow module not enabled")
            }
            return try await flowModule.send(amount: amount, to: recipientAddress, for: asset)
        }
    }
    
    public func getTransactionHistory(for chain: ChainConfig?) async throws -> [UnifiedTransaction] {
        logger.info("Getting transaction history for \(chain?.name ?? "all chains")")
        
        var allTransactions: [UnifiedTransaction] = []
        
        let chainsToQuery: [ChainConfig]
        if let chain = chain {
            chainsToQuery = [chain]
        } else {
            chainsToQuery = await chainConfigService.availableChains
        }
        
        for chainConfig in chainsToQuery {
            let chainTransactions: [UnifiedTransaction]
            
            switch chainConfig.type {
            case .bitcoin:
                guard let bitcoinModule = bitcoinModule else { continue }
                chainTransactions = try await bitcoinModule.getTransactionHistory(for: chainConfig)
                
            case .solana:
                guard let solanaModule = solanaModule else { continue }
                chainTransactions = try await solanaModule.getTransactionHistory(for: chainConfig)
                
            case .evm:
                guard let evmModule = evmModule else { continue }
                chainTransactions = try await evmModule.getTransactionHistory(for: chainConfig)
                
            case .flow:
                guard let flowModule = flowModule else { continue }
                chainTransactions = try await flowModule.getTransactionHistory(for: chainConfig)
            }
            
            allTransactions.append(contentsOf: chainTransactions)
        }
        
        return allTransactions.sorted { $0.date > $1.date }
    }
    
    public func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
        logger.info("Signing message on \(chain.name)")
        
        switch chain.type {
        case .bitcoin:
            guard let bitcoinModule = bitcoinModule else {
                throw WalletError.unsupportedOperation("Bitcoin module not enabled")
            }
            return try await bitcoinModule.signMessage(message, on: chain)
            
        case .solana:
            guard let solanaModule = solanaModule else {
                throw WalletError.unsupportedOperation("Solana module not enabled")
            }
            return try await solanaModule.signMessage(message, on: chain)
            
        case .evm:
            guard let evmModule = evmModule else {
                throw WalletError.unsupportedOperation("EVM module not enabled")
            }
            return try await evmModule.signMessage(message, on: chain)
            
        case .flow:
            guard let flowModule = flowModule else {
                throw WalletError.unsupportedOperation("Flow module not enabled")
            }
            return try await flowModule.signMessage(message, on: chain)
        }
    }
    
    // Flow-specific methods
    public func executeCadenceScript(_ script: String, arguments: [FlowArgument] = []) async throws -> String {
        guard let flowModule = flowModule else {
            throw WalletError.unsupportedOperation("Flow module not enabled")
        }
        return try await flowModule.executeScript(script, arguments: arguments)
    }
    
    public func executeCadenceTransaction(_ template: FlowTransactionTemplate) async throws -> UnifiedTransaction {
        guard let flowModule = flowModule else {
            throw WalletError.unsupportedOperation("Flow module not enabled")
        }
        return try await flowModule.executeTransaction(template)
    }
}

// MARK: - Protocol Definitions

public protocol ChainModule {
    func getBalance(for asset: CryptoAsset) async throws -> Double
    func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction
    func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction]
    func signMessage(_ message: String, on chain: ChainConfig) async throws -> String
}

// MARK: - Supporting Types

public struct FlowTransactionTemplate {
    public let script: String
    public let arguments: [FlowArgument]
    public let proposer: String
    public let authorizers: [String]
    public let payer: String
    public let gasLimit: Int
    
    public init(script: String, arguments: [FlowArgument] = [], proposer: String, authorizers: [String], payer: String, gasLimit: Int) {
        self.script = script
        self.arguments = arguments
        self.proposer = proposer
        self.authorizers = authorizers
        self.payer = payer
        self.gasLimit = gasLimit
    }
}

