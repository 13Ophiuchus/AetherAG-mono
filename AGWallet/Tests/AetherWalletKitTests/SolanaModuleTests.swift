import Foundation
import Testing
@testable import AetherWalletKit
import SolanaSwift

struct SolanaModuleTests {
	private let knownGoodBlockhash = "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud"
	private let recipientAddress = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"
	private let usdcMintAddress = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

	private func makeNativeSOLAsset(chain: ChainConfig) -> CryptoAsset {
		CryptoAsset(
			name: "Solana", symbol: "SOL",
			decimals: 9,
			contractAddress: nil,
			chainConfig: chain
		)
	}

	private func makeUSDCAsset(chain: ChainConfig) -> CryptoAsset {
		CryptoAsset(
			name: "USD Coin", symbol: "USDC",
			decimals: 6,
			contractAddress: usdcMintAddress,
			chainConfig: chain
		)
	}

	private func makeKeyManager(
		chain: ChainConfig,
		masterKey: Data = Data(repeating: 0x42, count: 32)
	) async throws -> KeyManagerActor {
		let keyManager = KeyManagerActor(
			storageProvider: InMemoryKeyStorageProvider()
		)

		try await keyManager.storePrivateKey(
			masterKey,
			for: "masterKey",
			requiresBiometrics: false
		)

		try await keyManager.storePrivateKey(
			masterKey,
			for: chain.chainId,
			requiresBiometrics: false
		)

		return keyManager
	}

	@Test("send broadcasts a native SOL transfer using the injected RPC client")
	func sendTransactionHappyPath() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			blockhashToReturn: knownGoodBlockhash,
			sendTransactionResult: "mock-native-sol-transaction-id"
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let transaction = try await solanaModule.send(
			amount: 0.5,
			to: recipientAddress,
			for: makeNativeSOLAsset(chain: chain())
		)

		guard case let .solana(solanaTransaction) = transaction else {
			Issue.record("Expected a Solana transaction")
			return
		}

		#expect(solanaTransaction.signature == mockClient.signedPayloadSignature)
		#expect(solanaTransaction.recentBlockhash == knownGoodBlockhash)
		#expect(mockClient.getRecentBlockhashCallCount == 1)
		#expect(mockClient.sendTransactionCallCount == 1)
		#expect(mockClient.lastSentTransaction != nil)
		#expect(mockClient.lastSendTransactionConfiguration?.encoding == "base64")
	}

	@Test("send fails with keychainError when no master key is stored")
	func sendFailsWithoutStoredKey() async throws {
		let chain = ChainConfig.mockSolanaChain
		let solanaModule = SolanaModule(
			keyManager: KeyManagerActor(
				storageProvider: InMemoryKeyStorageProvider()
			)
		)

		do {
			_ = try await solanaModule.send(
				amount: 0.5,
				to: recipientAddress,
				for: makeNativeSOLAsset(chain: chain())
			)
			Issue.record("Expected keychainError when no master key is stored")
		} catch let WalletError.keychainError(reason) {
			#expect(reason == "Master key not found")
		}
	}

	@Test("signMessage fails with keychainError when no master key is stored")
	func signMessageFailsWithoutStoredKey() async throws {
		let chain = ChainConfig.mockSolanaChain
		let solanaModule = SolanaModule(
			keyManager: KeyManagerActor(
				storageProvider: InMemoryKeyStorageProvider()
			)
		)

		do {
			_ = try await solanaModule.signMessage(
				"AetherWalletKit test message",
				on: chain()
			)
			Issue.record("Expected keychainError when no master key is stored")
		} catch let WalletError.keychainError(reason) {
			#expect(reason == "Master key not found")
		}
	}

	@Test("getBalance returns native SOL balance converted from lamports")
	func getBalanceHappyPath() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			balanceToReturn: 1_250_000_000
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let balance = try await solanaModule.getBalance(
			for: makeNativeSOLAsset(chain: chain())
		)

		#expect(balance == 1.25)
		#expect(mockClient.getBalanceCallCount == 1)
	}

	@Test("getBalance fails with keychainError when no master key is stored")
	func getBalanceFailsWithoutStoredKey() async throws {
		let chain = ChainConfig.mockSolanaChain
		let solanaModule = SolanaModule(
			keyManager: KeyManagerActor(
				storageProvider: InMemoryKeyStorageProvider()
			)
		)

		do {
			_ = try await solanaModule.getBalance(
				for: makeNativeSOLAsset(chain: chain())
			)
			Issue.record("Expected keychainError when no master key is stored")
		} catch let WalletError.keychainError(reason) {
			#expect(reason == "Master key not found")
		}
	}

	@Test("getBalance returns SPL token balance from the associated token account")
	func getBalanceSPLHappyPath() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			tokenBalanceToReturn: 42.5
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let balance = try await solanaModule.getBalance(
			for: makeUSDCAsset(chain: chain())
		)

		#expect(balance == 42.5)
		#expect(mockClient.getTokenAccountBalanceCallCount == 1)
	}

	@Test("send broadcasts an SPL token transfer")
	func sendSPLTransactionHappyPath() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			blockhashToReturn: knownGoodBlockhash,
			accountExistsToReturn: true,
			sendTransactionResult: "mock-spl-transaction-id"
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let transaction = try await solanaModule.send(
			amount: 1.25,
			to: recipientAddress,
			for: makeUSDCAsset(chain: chain())
		)

		guard case let .solana(solanaTransaction) = transaction else {
			Issue.record("Expected a Solana transaction")
			return
		}

		#expect(solanaTransaction.recentBlockhash == knownGoodBlockhash)
		#expect(mockClient.accountExistsCallCount == 1)
		#expect(mockClient.getRecentBlockhashCallCount == 1)
		#expect(mockClient.sendTransactionCallCount == 1)
		#expect(mockClient.lastSentTransaction != nil)
		#expect(mockClient.lastSendTransactionConfiguration?.encoding == "base64")
	}

	@Test("send aborts SPL transfer when recipient ATA lookup fails")
	func sendSPLTransactionAbortsWhenRecipientATALookupFails() async throws {
		struct LookupError: Error {}

		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			blockhashToReturn: knownGoodBlockhash,
			accountExistsError: LookupError()
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		do {
			_ = try await solanaModule.send(
				amount: 1.25,
				to: recipientAddress,
				for: makeUSDCAsset(chain: chain())
			)
			Issue.record("Expected recipient ATA lookup error")
		} catch is LookupError {
				// Expected.
		}

		#expect(mockClient.accountExistsCallCount == 1)
		#expect(mockClient.getRecentBlockhashCallCount == 0)
		#expect(mockClient.sendTransactionCallCount == 0)
	}

	@Test("send rejects SPL amounts exceeding configured token precision")
	func sendRejectsSPLAmountExceedingConfiguredPrecision() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())
		let mockClient = MockSolanaRPCClient()

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		do {
			_ = try await solanaModule.send(
				amount: 1.0000001,
				to: recipientAddress,
				for: makeUSDCAsset(chain: chain())
			)
			Issue.record("Expected invalid amount error")
		} catch is WalletError {
				// Expected.
		}

		#expect(mockClient.accountExistsCallCount == 0)
		#expect(mockClient.getRecentBlockhashCallCount == 0)
		#expect(mockClient.sendTransactionCallCount == 0)
	}

	@Test("send creates a missing recipient ATA before SPL transfer")
	func sendSPLTransactionCreatesMissingRecipientATA() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			blockhashToReturn: knownGoodBlockhash,
			accountExistsToReturn: false,
			sendTransactionResult: "mock-create-ata-transaction-id"
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		_ = try await solanaModule.send(
			amount: 1.25,
			to: recipientAddress,
			for: makeUSDCAsset(chain: chain())
		)

		#expect(mockClient.accountExistsCallCount == 1)
		#expect(mockClient.getRecentBlockhashCallCount == 1)
		#expect(mockClient.sendTransactionCallCount == 1)
	}

	@Test("send rejects invalid native SOL amounts before broadcasting")
	func sendRejectsInvalidNativeSOLAmounts() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())
		let mockClient = MockSolanaRPCClient()

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let nativeSOL = makeNativeSOLAsset(chain: chain())

		for invalidAmount in [
			0.0,
			-1.0,
			Double.nan,
			Double.infinity,
			0.0000000001,
		] {
			do {
				_ = try await solanaModule.send(
					amount: invalidAmount,
					to: recipientAddress,
					for: nativeSOL
				)
				Issue.record("Expected invalid amount error for \(invalidAmount)")
			} catch is WalletError {
					// Expected.
			}
		}

		#expect(mockClient.getRecentBlockhashCallCount == 0)
		#expect(mockClient.sendTransactionCallCount == 0)
	}

	@Test("send accepts lamport-aligned native SOL amounts")
	func sendAcceptsExactNativeSOLAmounts() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())

		let mockClient = MockSolanaRPCClient(
			blockhashToReturn: knownGoodBlockhash,
			sendTransactionResult: "mock-lamport-aligned-transaction-id"
		)

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let nativeSOL = makeNativeSOLAsset(chain: chain())

		_ = try await solanaModule.send(
			amount: 1.000000001,
			to: recipientAddress,
			for: nativeSOL
		)

		_ = try await solanaModule.send(
			amount: 0.000000001,
			to: recipientAddress,
			for: nativeSOL
		)

		#expect(mockClient.getRecentBlockhashCallCount == 2)
		#expect(mockClient.sendTransactionCallCount == 2)
	}

	@Test("send rejects native SOL amounts above UInt64 lamport range")
	func sendRejectsNativeSOLAmountAboveLamportRange() async throws {
		let chain = ChainConfig.mockSolanaChain
		let keyManager = try await makeKeyManager(chain: chain())
		let mockClient = MockSolanaRPCClient()

		let solanaModule = SolanaModule(
			keyManager: keyManager,
			rpcClientOverride: mockClient
		)

		let amountAboveMaximumLamports = Double(UInt64.max) / 1_000_000_000 + 1

		do {
			_ = try await solanaModule.send(
				amount: amountAboveMaximumLamports,
				to: recipientAddress,
				for: makeNativeSOLAsset(chain: chain())
			)
			Issue.record("Expected invalid amount error")
		} catch is WalletError {
				// Expected.
		}

		#expect(mockClient.getRecentBlockhashCallCount == 0)
		#expect(mockClient.sendTransactionCallCount == 0)
	}
}

final class MockSolanaRPCClient: SolanaRPCClientProtocol, @unchecked Sendable {
	func getSignaturesForAddress(address: String, configs: SolanaSwift.RequestConfiguration?) async throws -> [SolanaSwift.SignatureInfo] {
		return []
	}

	func getTransaction(signature: String, commitment: SolanaSwift.Commitment?) async throws -> SolanaSwift.TransactionInfo? {
		return nil
	}

	let blockhashToReturn: String
	let balanceToReturn: UInt64
	let tokenBalanceToReturn: Double?
	let accountExistsToReturn: Bool
	let accountExistsError: Error?
	let sendTransactionResult: String

	private(set) var getRecentBlockhashCallCount = 0
	private(set) var sendTransactionCallCount = 0
	private(set) var getBalanceCallCount = 0
	private(set) var getTokenAccountBalanceCallCount = 0
	private(set) var accountExistsCallCount = 0
	private(set) var lastSentTransaction: String?
	private(set) var lastSendTransactionConfiguration: RequestConfiguration?

	let signedPayloadSignature = "mock-signed-solana-payload"

	init(
		blockhashToReturn: String = "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud",
		balanceToReturn: UInt64 = 0,
		tokenBalanceToReturn: Double? = nil,
		accountExistsToReturn: Bool = true,
		accountExistsError: Error? = nil,
		sendTransactionResult: String = "mock-solana-transaction-id"
	) {
		self.blockhashToReturn = blockhashToReturn
		self.balanceToReturn = balanceToReturn
		self.tokenBalanceToReturn = tokenBalanceToReturn
		self.accountExistsToReturn = accountExistsToReturn
		self.accountExistsError = accountExistsError
		self.sendTransactionResult = sendTransactionResult
	}

	func getRecentBlockhash(
		commitment: Commitment?
	) async throws -> String {
		getRecentBlockhashCallCount += 1
		return blockhashToReturn
	}

	func sendTransaction(
		transaction: String,
		configs: RequestConfiguration
	) async throws -> String {
		sendTransactionCallCount += 1
		lastSentTransaction = transaction
		lastSendTransactionConfiguration = configs
		return sendTransactionResult
	}

	func getBalance(
		account: String,
		commitment: Commitment?
	) async throws -> UInt64 {
		getBalanceCallCount += 1
		return balanceToReturn
	}

	func getTokenAccountBalance(
		pubkey: String,
		commitment: Commitment?
	) async throws -> TokenAccountBalance {
		getTokenAccountBalanceCallCount += 1

		return TokenAccountBalance(
			uiAmount: tokenBalanceToReturn, amount: "0",
			decimals: 6,
			uiAmountString: tokenBalanceToReturn.map { String($0) }
		)
	}

	func accountExists(account: String) async throws -> Bool {
		accountExistsCallCount += 1

		if let accountExistsError {
			throw accountExistsError
		}

		return accountExistsToReturn
	}
}

