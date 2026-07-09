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
