import Foundation

public enum ChainType: String, Codable, Sendable, CaseIterable {
    case bitcoin
    case evm
    case solana
    case flow
}

public enum ChainNetwork: String, Codable, Sendable, CaseIterable {
    case mainnet
    case testnet
    case signet
    case regtest
    case devnet
    case local
}

public enum EndpointRole: String, Codable, Sendable, CaseIterable {
    case rpc
    case broadcast
    case explorerAPI
    case websocket
    case indexer
}

public struct NetworkEndpointSet: Codable, Sendable, Equatable {
    public let network: ChainNetwork
    public let endpointsByRole: [EndpointRole: [URL]]
    public let explorerUrl: URL?

    public init(
        network: ChainNetwork,
        endpointsByRole: [EndpointRole: [URL]],
        explorerUrl: URL? = nil
    ) {
        self.network = network
        self.endpointsByRole = endpointsByRole
        self.explorerUrl = explorerUrl
    }

    public func endpoints(for role: EndpointRole) -> [URL] {
        endpointsByRole[role] ?? []
    }

    public func primaryEndpoint(for role: EndpointRole) -> URL? {
        endpoints(for: role).first
    }
}

public struct ChainConfig: Codable, Sendable, Equatable {
    public let chainId: String
    public let name: String
    public let type: ChainType
    public let activeNetwork: ChainNetwork
    public let networks: [ChainNetwork: NetworkEndpointSet]
    public let derivationPath: String
    public let nativeAssetSymbol: String
    public let customConfig: [String: String]?

    public init(
        chainId: String,
        name: String,
        type: ChainType,
        activeNetwork: ChainNetwork,
        networks: [ChainNetwork: NetworkEndpointSet],
        derivationPath: String,
        nativeAssetSymbol: String,
        customConfig: [String: String]? = nil
    ) {
        self.chainId = chainId
        self.name = name
        self.type = type
        self.activeNetwork = activeNetwork
        self.networks = networks
        self.derivationPath = derivationPath
        self.nativeAssetSymbol = nativeAssetSymbol
        self.customConfig = customConfig
    }

    /// Legacy-compatible initializer preserving the old single-network, flat-URL-list shape.
    /// New call sites should prefer the `networks:` initializer for real multi-network support.
    public init(
        chainId: String,
        name: String,
        type: ChainType,
        rpcEndpoints: [URL],
        explorerUrl: URL? = nil,
        derivationPath: String,
        nativeAssetSymbol: String,
        customConfig: [String: String]? = nil,
        network: ChainNetwork = .mainnet
    ) {
        self.chainId = chainId
        self.name = name
        self.type = type
        self.activeNetwork = network
        self.networks = [
            network: NetworkEndpointSet(
                network: network,
                endpointsByRole: [.rpc: rpcEndpoints, .broadcast: rpcEndpoints],
                explorerUrl: explorerUrl
            )
        ]
        self.derivationPath = derivationPath
        self.nativeAssetSymbol = nativeAssetSymbol
        self.customConfig = customConfig
    }
}

public extension ChainConfig {
    var activeNetworkConfig: NetworkEndpointSet? {
        networks[activeNetwork]
    }

    /// Legacy accessor — existing BitcoinModule/EVMModule code keeps compiling.
    /// Prefer `primaryEndpoint(for: .rpc)` in new code.
    var rpcEndpoints: [URL] {
        activeNetworkConfig?.endpoints(for: .rpc) ?? []
    }

    var broadcastEndpoints: [URL] {
        let endpoints = activeNetworkConfig?.endpoints(for: .broadcast) ?? []
        return endpoints.isEmpty ? rpcEndpoints : endpoints
    }

    var websocketEndpoints: [URL] {
        activeNetworkConfig?.endpoints(for: .websocket) ?? []
    }

    var indexerEndpoints: [URL] {
        activeNetworkConfig?.endpoints(for: .indexer) ?? []
    }

    var explorerUrl: URL? {
        activeNetworkConfig?.explorerUrl
    }

    func primaryEndpoint(for role: EndpointRole) -> URL? {
        activeNetworkConfig?.primaryEndpoint(for: role)
    }

    func endpoints(for role: EndpointRole) -> [URL] {
        activeNetworkConfig?.endpoints(for: role) ?? []
    }

    /// Returns a copy of this config switched to a different configured network.
    func withActiveNetwork(_ network: ChainNetwork) -> ChainConfig {
        ChainConfig(
            chainId: chainId,
            name: name,
            type: type,
            activeNetwork: network,
            networks: networks,
            derivationPath: derivationPath,
            nativeAssetSymbol: nativeAssetSymbol,
            customConfig: customConfig
        )
    }

    var supportedNetworks: [ChainNetwork] {
        Array(networks.keys)
    }
}

// MARK: - Asset & Transaction Models

public struct CryptoAsset: Codable, Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let decimals: Int
    public let contractAddress: String?
    public let chainConfig: ChainConfig
    public let balance: Double

    public init(
        name: String,
        symbol: String,
        decimals: Int,
        contractAddress: String? = nil,
        chainConfig: ChainConfig,
        balance: Double = 0.0
    ) {
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.contractAddress = contractAddress
        self.chainConfig = chainConfig
        self.balance = balance
    }
}

// Bitcoin

public struct BitcoinTransaction: Codable, Sendable {
    public let txId: String
    public let inputs: [BitcoinInput]
    public let outputs: [BitcoinOutput]
    public let fee: Double
    public let blockHeight: Int?
    public let timestamp: Date

    public init(
        txId: String,
        inputs: [BitcoinInput],
        outputs: [BitcoinOutput],
        fee: Double,
        blockHeight: Int? = nil,
        timestamp: Date
    ) {
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

    public init(
        previousTxId: String,
        outputIndex: Int,
        value: Double = 0.0,
        address: String = ""
    ) {
        self.previousTxId = previousTxId
        self.outputIndex = outputIndex
        self.value = value
        self.address = address
    }
}

public struct BitcoinOutput: Codable, Sendable {
    public let value: Double
    public let address: String

    public init(value: Double, address: String) {
        self.value = value
        self.address = address
    }
}

// Solana

public struct SolanaTransaction: Codable, Sendable {
    public let signature: String
    public let recentBlockhash: String
    public let instructions: [SolanaInstruction]
    public let fee: Double
    public let slot: UInt64?
    public let timestamp: Date

    public init(
        signature: String,
        recentBlockhash: String,
        instructions: [SolanaInstruction],
        fee: Double,
        slot: UInt64? = nil,
        timestamp: Date
    ) {
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
    public let accounts: [SolanaAccountMeta]
    public let data: String

    public init(programId: String, accounts: [SolanaAccountMeta], data: String) {
        self.programId = programId
        self.accounts = accounts
        self.data = data
    }
}

public struct SolanaAccountMeta: Codable, Sendable {
    public let publicKey: String
    public let isSigner: Bool
    public let isWritable: Bool

    public init(publicKey: String, isSigner: Bool, isWritable: Bool) {
        self.publicKey = publicKey
        self.isSigner = isSigner
        self.isWritable = isWritable
    }
}

// EVM

public struct EVMTransaction: Codable, Sendable {
    public let hash: String
    public let from: String
    public let to: String
    public let value: String
    public let gasPrice: String
    public let gasLimit: String
    public let nonce: Int
    public let chainId: Int
    public let blockNumber: Int?
    public let timestamp: Date

    public init(
        hash: String,
        from: String,
        to: String,
        value: String,
        gasPrice: String,
        gasLimit: String,
        nonce: Int,
        chainId: Int,
        blockNumber: Int? = nil,
        timestamp: Date
    ) {
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

// Flow

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
    case executed
    case committed
    case failed
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

    public init(
        id: String,
        script: String,
        arguments: [FlowArgument],
        proposer: String,
        authorizers: [String],
        payer: String,
        gasLimit: Int,
        status: FlowTransactionStatus,
        timestamp: Date
    ) {
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

// Unified transaction wrapper

public enum UnifiedTransaction: Codable, Sendable {
    case bitcoin(BitcoinTransaction)
    case solana(SolanaTransaction)
    case evm(EVMTransaction)
    case flow(FlowTransaction)
}

public extension UnifiedTransaction {
    var date: Date {
        switch self {
        case .bitcoin(let tx): return tx.timestamp
        case .solana(let tx): return tx.timestamp
        case .evm(let tx):     return tx.timestamp
        case .flow(let tx):    return tx.timestamp
        }
    }
}
