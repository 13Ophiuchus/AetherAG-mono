import Foundation

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
        enableFlow: Bool = false
    ) {
        self.keyManager = keyManager
        self.chainConfigService = chainConfigService
        
        self.bitcoinModule = enableBitcoin ? BitcoinModule(keyManager: keyManager) : nil
        self.solanaModule = enableSolana ? SolanaModule(keyManager: keyManager) : nil
        self.evmModule = enableEVM ? EVMModule(keyManager: keyManager) : nil
        self.flowModule = enableFlow ? FlowModule(keyManager: keyManager) : nil
    }
    
    /// Fetches the current balance for a given asset on its configured chain.
    /// - Parameter asset: The crypto asset (native or token) to query.
    /// - Returns: The balance as a `Double` in the asset's native decimal units.
    /// - Throws: `WalletError.unsupportedOperation` if the asset's chain module is disabled.
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
    
    /// Sends an amount of a given asset to a recipient address on its configured chain.
    /// - Parameters:
    ///   - amount: The amount to send, in the asset's native decimal units.
    ///   - recipientAddress: The destination address, formatted for the asset's chain.
    ///   - asset: The crypto asset (native or token) to send.
    /// - Returns: A `UnifiedTransaction` representing the broadcasted transaction.
    /// - Throws: `WalletError.unsupportedOperation` if the asset's chain module is disabled.
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
    
    /// Fetches recent transaction history, optionally scoped to a single chain.
    /// - Parameter chain: The chain to query, or `nil` to query all enabled chains.
    /// - Returns: Transactions merged across queried chains, sorted newest first.
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
    
    /// Signs an arbitrary message using the wallet's key for the given chain.
    /// - Parameters:
    ///   - message: The plaintext message to sign.
    ///   - chain: The chain whose signing scheme and key should be used.
    /// - Returns: The signature, encoded per the chain's convention (e.g. hex).
    /// - Throws: `WalletError.unsupportedOperation` if the chain's module is disabled.
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
        guard flowModule != nil else {
            throw WalletError.unsupportedOperation("Flow module not enabled")
        }
        // TODO: bridge FlowArgument -> Flow.Cadence.FValue once script execution is implemented
        throw WalletError.unsupportedOperation("Flow script execution not yet implemented")
    }
    
    public func executeCadenceTransaction(_ template: FlowTransactionTemplate) async throws -> UnifiedTransaction {
        guard flowModule != nil else {
            throw WalletError.unsupportedOperation("Flow module not enabled")
        }
        // TODO: FlowModule.executeTransaction was removed pending a proper
        // Flow.Transaction builder/signer (see FlowModule.swift TODO on send()).
        throw WalletError.unsupportedOperation("Cadence transaction execution not yet implemented")
    }
}

// MARK: - Protocol Definitions

