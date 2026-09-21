import Foundation
import SolanaSwift
import TweetNacl

	// Thin protocol over the exact SolanaSwift RPC calls SolanaModule needs.
	// Lets tests inject a mock client instead of hitting mainnet, while
	// production code defaults to the real JSONRPCAPIClient unchanged.
	// Not Sendable: JSONRPCAPIClient's internals (APIEndPoint, NetworkManager)
	// aren't Sendable upstream, so this protocol stays non-Sendable too.
	// SolanaModule itself is already @unchecked Sendable, which is sufficient.
protocol SolanaRPCClientProtocol {
	func getRecentBlockhash(commitment: Commitment?) async throws -> String
	func sendTransaction(transaction: String, configs: RequestConfiguration) async throws -> String
	func getBalance(account: String, commitment: Commitment?) async throws -> UInt64
	func getSignaturesForAddress(
		address: String,
		configs: RequestConfiguration?
	) async throws -> [SignatureInfo]
	func getTransaction(
		signature: String,
		commitment: Commitment?
	) async throws -> TransactionInfo?
	func getTokenAccountBalance(
		pubkey: String,
		commitment: Commitment?
	) async throws -> TokenAccountBalance
	func accountExists(account: String) async throws -> Bool
}

extension JSONRPCAPIClient: SolanaRPCClientProtocol {
	func accountExists(account: String) async throws -> Bool {
		let accountInfo: BufferInfo<EmptyInfo>? = try await getAccountInfo(account: account)
		return accountInfo != nil
	}
}

final class SolanaModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.SolanaModule")

		// Stored on an @unchecked Sendable class — acceptable since SolanaModule
		// already opts out of strict Sendable checking for its dependencies.
	private let rpcClientOverride: SolanaRPCClientProtocol?

	init(
		keyManager: KeyManagerActor,
		rpcClientOverride: SolanaRPCClientProtocol? = nil
	) {
		self.keyManager = keyManager
		self.rpcClientOverride = rpcClientOverride
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting Solana balance for \(asset.symbol)")

		let client = try resolvedRPCClient(for: asset.chainConfig)
		let address = try await getAddress(for: asset.chainConfig)

		if let mintAddress = asset.contractAddress {
			let owner = try PublicKey(string: address)
			let mint = try PublicKey(string: mintAddress)
			let ata = try PublicKey.associatedTokenAddress(
				walletAddress: owner,
				tokenMintAddress: mint,
				tokenProgramId: TokenProgram.id
			)

			let tokenBalance = try await client.getTokenAccountBalance(
				pubkey: ata.base58EncodedString,
				commitment: nil
			)

			return tokenBalance.uiAmount ?? 0.0
		}

		let lamports = try await client.getBalance(
			account: address,
			commitment: nil
		)
		return Double(lamports) / 1_000_000_000
	}

	func send(
		amount: Double,
		to recipientAddress: String,
		for asset: CryptoAsset
	) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")

		let client = try resolvedRPCClient(for: asset.chainConfig)

		if let mintAddress = asset.contractAddress {
			_ = try Self.validatedBaseUnits(
				from: amount,
				decimals: asset.decimals,
				assetSymbol: asset.symbol
			)

			let senderAddress = try await getAddress(for: asset.chainConfig)
			let recipient = try PublicKey(string: recipientAddress)
			let mint = try PublicKey(string: mintAddress)

			let recipientATA = try PublicKey.associatedTokenAddress(
				walletAddress: recipient,
				tokenMintAddress: mint,
				tokenProgramId: TokenProgram.id
			)

			let recipientATAExists = try await client.accountExists(
				account: recipientATA.base58EncodedString
			)
			let recentBlockhash = try await client.getRecentBlockhash(
				commitment: nil
			)

			let signedPayload = try await keyManager.signSPLTransferPayload(
				mint: mintAddress,
				from: senderAddress,
				to: recipientAddress,
				amount: amount,
				decimals: asset.decimals,
				recipientATAExists: recipientATAExists,
				recentBlockhash: recentBlockhash,
				chain: asset.chainConfig
			)

			let transactionId = try await client.sendTransaction(
				transaction: signedPayload.serializedTransactionBase64,
				configs: RequestConfiguration(encoding: "base64")!
			)

			logger.info(
				"Broadcasted SPL transfer with signature \(signedPayload.signature), txid \(transactionId)"
			)

			let unifiedTransaction = SolanaTransaction(
				signature: signedPayload.signature,
				recentBlockhash: recentBlockhash,
				instructions: [],
				fee: 0.000005,
				slot: nil,
				timestamp: Date()
			)

			return .solana(unifiedTransaction)
		}

		let lamports = try Self.solanaLamports(from: amount)
		let senderAddress = try await getAddress(for: asset.chainConfig)
		let recentBlockhash = try await client.getRecentBlockhash(commitment: nil)

		let lamportsLE = withUnsafeBytes(of: lamports.littleEndian) {
			Data($0)
		}

		let transferDiscriminator: [UInt8] = [2, 0, 0, 0]
		var instructionData = Data(transferDiscriminator)
		instructionData.append(lamportsLE)

		let dataHex = instructionData
			.map { String(format: "%02x", $0) }
			.joined()

		let instruction = SolanaInstruction(
			programId: SystemProgram.id.base58EncodedString,
			accounts: [
				SolanaAccountMeta(
					publicKey: senderAddress,
					isSigner: true,
					isWritable: true
				),
				SolanaAccountMeta(
					publicKey: recipientAddress,
					isSigner: false,
					isWritable: true
				),
			],
			data: dataHex
		)

		let transaction = SolanaTransaction(
			signature: "",
			recentBlockhash: recentBlockhash,
			instructions: [instruction],
			fee: 0.000005,
			slot: nil,
			timestamp: Date()
		)

		let signedPayload = try await signTransferInternal(
			transaction,
			chain: asset.chainConfig
		)

		let transactionId = try await client.sendTransaction(
			transaction: signedPayload.serializedTransactionBase64,
			configs: RequestConfiguration(encoding: "base64")!
		)

		logger.info(
			"Broadcasted Solana transfer with signature \(signedPayload.signature), txid \(transactionId)"
		)

		let unifiedTransaction = SolanaTransaction(
			signature: signedPayload.signature,
			recentBlockhash: recentBlockhash,
			instructions: [instruction],
			fee: 0.000005,
			slot: nil,
			timestamp: Date()
		)

		return .solana(unifiedTransaction)
	}

	func getTransactionHistory(
		for chain: ChainConfig
	) async throws -> [UnifiedTransaction] {
		logger.info("Getting Solana transaction history for \(chain.name)")

		let client = try resolvedRPCClient(for: chain)
		let address = try await getAddress(for: chain)

		let signatureInfos = try await client.getSignaturesForAddress(
			address: address,
			configs: nil
		)

		var transactions: [UnifiedTransaction] = []

		for signatureInfo in signatureInfos {
			guard let transactionInfo = try await client.getTransaction(
				signature: signatureInfo.signature,
				commitment: nil
			) else {
				continue
			}

			let timestamp = signatureInfo.blockTime
				.map { Date(timeIntervalSince1970: TimeInterval($0)) }
			?? Date()

			let transaction = SolanaTransaction(
				signature: signatureInfo.signature,
				recentBlockhash: "",
				instructions: [],
				fee: transactionInfo.meta?.fee.map {
					Double($0) / 1_000_000_000
				} ?? 0,
				slot: transactionInfo.slot,
				timestamp: timestamp
			)

			transactions.append(.solana(transaction))
		}

		return transactions
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on Solana")
		return try await signMessageInternal(message, chain: chain)
	}

	public func getReceiveAddress(for chain: ChainConfig) async throws -> String {
		try await getAddress(for: chain)
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

	private func resolvedRPCClient(
		for chain: ChainConfig
	) throws -> SolanaRPCClientProtocol {
		if let rpcClientOverride {
			return rpcClientOverride
		}

		return try rpcClient(for: chain)
	}

	private static func validatedBaseUnits(
		from amount: Double,
		decimals: Int,
		assetSymbol: String
	) throws -> UInt64 {
		guard amount.isFinite, amount > 0 else {
			throw WalletError.invalidAmount(
				"\(assetSymbol) amount must be finite and greater than zero"
			)
		}

		guard (0 ... 18).contains(decimals) else {
			throw WalletError.invalidAmount(
				"\(assetSymbol) decimal precision must be between 0 and 18"
			)
		}

		let scale = Decimal(sign: .plus, exponent: decimals, significand: 1)
		var scaledAmount = Decimal(amount) * scale
		var roundedAmount = Decimal()

		NSDecimalRound(&roundedAmount, &scaledAmount, 0, .plain)

		// `amount` enters this API as a binary Double. Accept only the tiny
		// conversion error around an exact base-unit value, never a material
		// fractional base-unit amount.
		let representationTolerance = Decimal(string: "0.000001")!
		let roundingDifference = abs(scaledAmount - roundedAmount)

		guard roundingDifference <= representationTolerance else {
			throw WalletError.invalidAmount(
				"\(assetSymbol) amount exceeds supported precision of \(decimals) decimals"
			)
		}

		guard roundedAmount <= Decimal(UInt64.max) else {
			throw WalletError.invalidAmount(
				"\(assetSymbol) amount exceeds UInt64 base-unit range"
			)
		}

		let baseUnits = NSDecimalNumber(decimal: roundedAmount).uint64Value

		guard baseUnits > 0 else {
			throw WalletError.invalidAmount(
				"\(assetSymbol) amount cannot be represented in base units"
			)
		}

		return baseUnits
	}

	private static func solanaLamports(from amount: Double) throws -> UInt64 {
		try validatedBaseUnits(
			from: amount,
			decimals: 9,
			assetSymbol: "SOL"
		)
	}

	private func getAddress(for chain: ChainConfig) async throws -> String {
		let publicKey = try await getPublicKey(for: chain)
		return publicKey.base58EncodedString
	}

	private func getPublicKey(for chain: ChainConfig) async throws -> PublicKey {
		let seed = try await getPrivateKey(for: chain)
		let keyPair = try NaclSign.KeyPair.keyPair(fromSeed: seed)
		let account = try KeyPair(secretKey: keyPair.secretKey)
		return account.publicKey
	}

	private func getPrivateKey(for chain: ChainConfig) async throws -> Data {
		guard let privateKey = try await keyManager.retrievePrivateKey(
			for: chain.chainId
		) else {
			throw WalletError.keychainError("Master key not found")
		}

		return privateKey
	}

	private func signMessageInternal(
		_ message: String,
		chain: ChainConfig
	) async throws -> String {
		try await keyManager.signSolanaMessage(message, chain: chain)
	}

	private func signTransferInternal(
		_ transaction: SolanaTransaction,
		chain: ChainConfig
	) async throws -> KeyManagerActor.SolanaSignedPayload {
		try await keyManager.signSolanaTransferPayload(
			transaction,
			chain: chain
		)
	}
}
