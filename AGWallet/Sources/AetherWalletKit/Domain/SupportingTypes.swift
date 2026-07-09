import Foundation

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

public enum ChainConfigurationError: Error, LocalizedError {
	case chainAlreadyExists
	case chainNotFound

	public var errorDescription: String? {
		switch self {
			case .chainAlreadyExists:
				return "A chain with this ID already exists."
			case .chainNotFound:
				return "The specified chain could not be found."
		}
	}
}

	// MARK: - ChainModule Protocol

public protocol ChainModule: Sendable {
	func getBalance(for asset: CryptoAsset) async throws -> Double
	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction
	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction]
	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String
}

