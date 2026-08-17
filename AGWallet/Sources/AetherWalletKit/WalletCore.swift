import Foundation
import Flow

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

    // MARK: - getBalance

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

    // MARK: - send

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

    // MARK: - getTransactionHistory

    public func getTransactionHistory(for chain: ChainConfig?) async throws -> [UnifiedTransaction] {
        logger.info("Getting transaction history for \(chain?.name ?? "all chains")")
        var allTransactions: [UnifiedTransaction] = []
        let chains: [ChainConfig]
        if let chain = chain {
            chains = [chain]
        } else {
            chains = await chainConfigService.getPredefinedChains()
        }
        for chainConfig in chains {
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

    // MARK: - signMessage

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

    // MARK: - getReceiveAddress

    public func getReceiveAddress(for chain: ChainConfig) async throws -> String {
        logger.info("Getting receive address for \(chain.name)")
        switch chain.type {
        case .bitcoin:
            guard let bitcoinModule = bitcoinModule else {
                throw WalletError.unsupportedOperation("Bitcoin module not enabled")
            }
            return try await bitcoinModule.getReceiveAddress(for: chain)
        case .solana:
            guard let solanaModule = solanaModule else {
                throw WalletError.unsupportedOperation("Solana module not enabled")
            }
            return try await solanaModule.getReceiveAddress(for: chain)
        case .evm:
            guard let evmModule = evmModule else {
                throw WalletError.unsupportedOperation("EVM module not enabled")
            }
            return try await evmModule.getReceiveAddress(for: chain)
        case .flow:
            guard let flowModule = flowModule else {
                throw WalletError.unsupportedOperation("Flow module not enabled")
            }
            return try await flowModule.getReceiveAddress(for: chain)
        }
    }

    // MARK: - executeFlowScript

    /// Executes a read-only Cadence script on the Flow blockchain. This is
    /// Flow-specific (not part of the shared ChainModule protocol shared by
    /// Bitcoin/EVM/Solana), so it is exposed as its own facade method rather
    /// than being routed through a chain-type switch like the other operations.
    public func executeFlowScript(
        _ script: String,
        arguments: [Flow.Cadence.FValue],
        on chain: ChainConfig
    ) async throws -> Flow.Cadence.FValue {
        logger.info("Executing Flow script on \(chain.name)")
        guard chain.type == .flow else {
            throw WalletError.unsupportedOperation("executeFlowScript requires a Flow ChainConfig")
        }
        guard let flowModule = flowModule else {
            throw WalletError.unsupportedOperation("Flow module not enabled")
        }
        return try await flowModule.executeScript(script, arguments: arguments, on: chain)
    }
}

// MARK: - Protocol Definitions
