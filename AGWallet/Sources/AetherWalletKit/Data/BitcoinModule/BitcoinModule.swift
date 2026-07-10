import Foundation

final class BitcoinModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.BitcoinModule")
	private let session: URLSession

	init(
		keyManager: KeyManagerActor,
		session: URLSession = .shared
	) {
		self.keyManager = keyManager
		self.session = session
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting Bitcoin balance for \(asset.chainConfig.name)")

		let address = try await getAddress(for: asset.chainConfig)
		let client = try esploraClient(for: asset.chainConfig)

		let utxos = try await client.getUTXOs(for: address)
		let totalSatoshis = utxos.reduce(Int64(0)) { $0 + $1.valueSatoshis }

		return Double(totalSatoshis) / 100_000_000
	}

	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) BTC to \(recipientAddress)")

		let fromAddress = try await getAddress(for: asset.chainConfig)
		let client = try esploraClient(for: asset.chainConfig)

		let utxos = try await client.getUTXOs(for: fromAddress)
		let transaction = try buildTransaction(
			from: fromAddress,
			to: recipientAddress,
			amount: amount,
			utxos: utxos,
			chain: asset.chainConfig
		)

		let signedRawTransaction = try await signTransaction(transaction, for: asset.chainConfig)
		let txId = try await client.broadcast(rawTransaction: signedRawTransaction)

		logger.info("Successfully broadcasted Bitcoin transaction with ID: \(txId)")

		let unifiedTx = BitcoinTransaction(
			txId: txId,
			inputs: [],
			outputs: [],
			fee: 0.0001,
			blockHeight: nil,
			timestamp: Date()
		)

		return .bitcoin(unifiedTx)
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting Bitcoin transaction history for \(chain.name)")

		let address = try await getAddress(for: chain)
		let client = try esploraClient(for: chain)

		return try await client.getTransactionHistory(for: address)
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on Bitcoin: \(message)")
		throw WalletError.unsupportedOperation("Bitcoin message signing not yet implemented")
	}

		// MARK: - Private Helpers

	private func esploraClient(for chain: ChainConfig) throws -> EsploraClient {
		guard let endpoint = chain.primaryEndpoint(for: .rpc) else {
			throw WalletError.chainConfigurationError("No RPC endpoint configured for \(chain.name) [\(chain.activeNetwork.rawValue)]")
		}

		return BitcoinEsploraClient(
			baseURL: endpoint,
			session: session
		)
	}

	private func getAddress(for chain: ChainConfig) async throws -> String {
		throw WalletError.unsupportedOperation("Bitcoin address derivation not yet implemented")
	}

	private func buildTransaction(
		from: String,
		to: String,
		amount: Double,
		utxos: [UTXO],
		chain: ChainConfig
	) throws -> BitcoinTxDraft {
		let amountInSatoshis = Int64(amount * 100_000_000)

		return BitcoinTxDraft(
			from: from,
			to: to,
			amountInSatoshis: amountInSatoshis,
			utxos: utxos
		)
	}

	private func signTransaction(_ transaction: BitcoinTxDraft, for chain: ChainConfig) async throws -> String {
		throw WalletError.unsupportedOperation("Bitcoin transaction signing not yet implemented")
	}

    // Helper that delegates Bitcoin message signing to KeyManagerActor.
    private func signMessageInternal(_ message: String, chain: ChainConfig) async throws -> String {
        try await keyManager.signBitcoinMessage(message, chain: chain)
    }

    // Helper that delegates Bitcoin transaction signing to KeyManagerActor.
    private func signTransactionInternal(_ draft: BitcoinTxDraft, chain: ChainConfig) async throws -> String {
        try await keyManager.signBitcoinTransaction(draft, chain: chain)
    }
}
