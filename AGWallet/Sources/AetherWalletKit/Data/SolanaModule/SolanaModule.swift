import Foundation
import SolanaSwift

final class SolanaModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.SolanaModule")

	init(keyManager: KeyManagerActor) {
		self.keyManager = keyManager
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting Solana balance for \(asset.symbol)")

		let _ = try rpcClient(for: asset.chainConfig)
		let address = try await getAddress(for: asset.chainConfig)

		if asset.contractAddress != nil {
			throw WalletError.unsupportedOperation(
				"SPL token balance RPC not yet implemented for address \(address)"
			)
		} else {
			throw WalletError.unsupportedOperation(
				"Native SOL balance RPC not yet implemented for address \(address)"
			)
		}
	}

	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")

		let _ = try rpcClient(for: asset.chainConfig)

		if asset.contractAddress != nil {
			throw WalletError.unsupportedOperation("SPL token send not yet implemented")
		} else {
			throw WalletError.unsupportedOperation("Native SOL send not yet implemented")
		}
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting Solana transaction history for \(chain.name)")
		let _ = try rpcClient(for: chain)
		let address = try await getAddress(for: chain)

		throw WalletError.unsupportedOperation(
			"Solana transaction history RPC not yet implemented for address \(address)"
		)
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on Solana: \(message)")
		throw WalletError.unsupportedOperation("Solana message signing not yet implemented")
	}

		// MARK: - Private Helpers

	private func rpcClient(for chain: ChainConfig) throws -> JSONRPCAPIClient {
		guard let endpointURL = chain.primaryEndpoint(for: .rpc) else {
			throw WalletError.chainConfigurationError(
				"No RPC endpoint configured for \(chain.name) [\(chain.activeNetwork.rawValue)]"
			)
		}

		let endpoint = APIEndPoint(
			address: endpointURL.absoluteString,
			network: .mainnetBeta
		)

		return JSONRPCAPIClient(endpoint: endpoint)
	}

	private func getAddress(for chain: ChainConfig) async throws -> String {
		let publicKey = try await getPublicKey(for: chain)
		return publicKey.base58EncodedString
	}

	private func getPublicKey(for chain: ChainConfig) async throws -> PublicKey {
		let privateKey = try await getPrivateKey(for: chain)
		let account = try Account(secretKey: privateKey)
		return account.publicKey
	}

	private func getPrivateKey(for chain: ChainConfig) async throws -> Data {
		guard let privateKey = try await keyManager.retrievePrivateKey(for: "masterKey") else {
			throw WalletError.keychainError("Master key not found")
		}
		return privateKey
	}



    // Helper that delegates Solana message signing to KeyManagerActor.
    private func signMessageInternal(_ message: String, chain: ChainConfig) async throws -> String {
        try await keyManager.signSolanaMessage(message, chain: chain)
    }

    // Helper that delegates Solana transfer signing to KeyManagerActor.
    private func signTransferInternal(_ transaction: SolanaTransaction, chain: ChainConfig) async throws -> String {
        try await keyManager.signSolanaTransfer(transaction, chain: chain)
    }
}
