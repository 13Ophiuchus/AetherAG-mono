import Foundation
import Flow

final class FlowModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.FlowModule")

	init(keyManager: KeyManagerActor) {
		self.keyManager = keyManager
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting Flow balance for \(asset.symbol)")
		logger.warning("Flow balance lookup not yet implemented for current Flow SDK.")
		throw WalletError.unsupportedOperation("Flow balance lookup not yet implemented")
	}

	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")
		logger.warning("Flow transfer not yet implemented for current Flow SDK.")
		throw WalletError.unsupportedOperation("Flow token transfer not yet implemented")
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting Flow transaction history for \(chain.name)")
		logger.warning("Using mocked transaction history for Flow.")
		return []
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on Flow: \(message)")
		logger.warning("Flow message signing not yet implemented for current Flow SDK.")
		throw WalletError.unsupportedOperation("Flow message signing not yet implemented")
	}

		// MARK: - Flow Specific Methods

	func executeScript(_ script: String, arguments: [Flow.Cadence.FValue]) async throws -> Flow.Cadence.FValue {
		logger.info("Executing Flow script")
		logger.warning("Flow script execution bridge not yet implemented for current Flow SDK.")
		throw WalletError.unsupportedOperation("Flow script execution not yet implemented")
	}
}
