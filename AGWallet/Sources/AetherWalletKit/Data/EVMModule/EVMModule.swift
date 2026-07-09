import Foundation
import web3swift
import Web3Core
import BigInt

final class EVMModule: ChainModule, @unchecked Sendable {
	private let keyManager: KeyManagerActor
	private let logger = Logger(label: "AetherWalletKit.EVMModule")

	init(keyManager: KeyManagerActor) {
		self.keyManager = keyManager
	}

	func getBalance(for asset: CryptoAsset) async throws -> Double {
		logger.info("Getting EVM balance for \(asset.symbol)")
		let web3 = try await getWeb3(for: asset.chainConfig)
		let address = try await getEthereumAddress(for: asset.chainConfig)

		if let contractAddressString = asset.contractAddress {
				// ERC‑20 token balance
			guard let contractAddress = EthereumAddress(contractAddressString) else {
				throw WalletError.chainConfigurationError("Invalid contract address")
			}
			guard let contract = web3.contract(ERC20ABI, at: contractAddress) else {
				throw WalletError.chainConfigurationError("Failed to load ERC20 contract")
			}
			guard let readOp = contract.createReadOperation(
				"balanceOf",
				parameters: [address.address]
			) else {
				throw WalletError.chainConfigurationError("Failed to create read operation")
			}

			let result = try await readOp.callContractMethod()
			guard let balanceBigInt = result["0"] as? BigUInt else {
				throw WalletError.chainConfigurationError("Failed to decode balance")
			}

			return Double(balanceBigInt) / pow(10, Double(asset.decimals))
		} else {
				// Native chain token balance (ETH, MATIC, etc.)
			let balance = try await web3.eth.getBalance(for: address, onBlock: .latest)
			return Double(balance) / pow(10, 18)
		}
	}

	func send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction {
		logger.info("Sending \(amount) \(asset.symbol) to \(recipientAddress)")

		let web3 = try await getWeb3(for: asset.chainConfig)
		let fromAddress = try await getEthereumAddress(for: asset.chainConfig)

		guard let toAddress = EthereumAddress(recipientAddress) else {
			throw WalletError.chainConfigurationError("Invalid recipient address")
		}

		let privateKeyData = try await getPrivateKeyData(for: asset.chainConfig)

		var transaction: CodableTransaction

		if let contractAddressString = asset.contractAddress {
				// ERC‑20 token transfer
			guard let contractAddress = EthereumAddress(contractAddressString) else {
				throw WalletError.chainConfigurationError("Invalid contract address")
			}
			guard let contract = web3.contract(ERC20ABI, at: contractAddress) else {
				throw WalletError.chainConfigurationError("Failed to load ERC20 contract")
			}

			let amountBigInt = BigUInt(amount * pow(10, Double(asset.decimals)))

			guard let writeOp = contract.createWriteOperation(
				"transfer",
				parameters: [toAddress.address, amountBigInt]
			) else {
				throw WalletError.chainConfigurationError("Failed to create write operation")
			}

			transaction = writeOp.transaction
		} else {
				// Native token transfer
			let amountInWei = BigUInt(amount * pow(10, 18))
			transaction = CodableTransaction(to: toAddress, value: amountInWei)
		}

		transaction.from = fromAddress

		if let chainIdInt = Int(asset.chainConfig.chainId) {
			transaction.chainID = BigUInt(chainIdInt)
		} else {
			throw WalletError.chainConfigurationError(
				"Invalid numeric chainId '\(asset.chainConfig.chainId)'"
			)
		}

		try transaction.sign(privateKey: privateKeyData)

		guard let encodedTx = transaction.encode(for: .transaction) else {
			throw WalletError.chainConfigurationError("Failed to encode signed transaction")
		}

		let result = try await web3.eth.send(raw: encodedTx)

		logger.info("Successfully broadcasted EVM transaction with hash: \(result.hash)")

		let unifiedTx = EVMTransaction(
			hash: result.hash,
			from: fromAddress.address,
			to: toAddress.address,
			value: String(amount),
			gasPrice: "",      // TODO: Populate with actual gas price
			gasLimit: "",      // TODO: Populate with actual gas limit
			nonce: 0,          // TODO: Populate with actual nonce
			chainId: Int(asset.chainConfig.chainId) ?? 0,
			blockNumber: nil,
			timestamp: Date()
		)

		return .evm(unifiedTx)
	}

	func getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction] {
		logger.info("Getting EVM transaction history for \(chain.name)")
			// This would typically involve a service like Etherscan or a full‑node query.
		logger.warning("Using mocked transaction history for EVM.")
		return []
	}

	func signMessage(_ message: String, on chain: ChainConfig) async throws -> String {
		logger.info("Signing message on EVM: \(message)")

		let privateKeyData = try await getPrivateKeyData(for: chain)

		guard let messageData = message.data(using: .utf8),
			  let hash = Utilities.hashPersonalMessage(messageData) else {
			throw WalletError.chainConfigurationError("Failed to hash message")
		}

		let (signature, _) = SECP256K1.signForRecovery(hash: hash, privateKey: privateKeyData)

		guard let signature else {
			throw WalletError.chainConfigurationError("Failed to sign message")
		}

		return signature.toHexString()
	}

		// MARK: - Private Helpers

	private func getWeb3(for chain: ChainConfig) async throws -> Web3 {
		guard let rpcURL = chain.primaryEndpoint(for: .rpc) else {
			throw WalletError.chainConfigurationError(
				"No RPC endpoint found for \(chain.name) [\(chain.activeNetwork.rawValue)]"
			)
		}

			// web3swift 3.x async factory
		return try await Web3.new(rpcURL)
	}

	private func getEthereumAddress(for chain: ChainConfig) async throws -> EthereumAddress {
		let privateKeyData = try await getPrivateKeyData(for: chain)

		guard let publicKey = Utilities.privateToPublic(privateKeyData),
			  let address = Utilities.publicToAddress(publicKey) else {
			throw WalletError.chainConfigurationError("Failed to derive address from private key")
		}

		return address
	}

	private func getPrivateKeyData(for chain: ChainConfig) async throws -> Data {
			// This assumes the master key is the EVM private key.
			// A real implementation would use the derivation path.
		guard let keyData = try await keyManager.retrievePrivateKey(for: "masterKey") else {
			throw WalletError.keychainError("Master key not found")
		}
		return keyData
	}
}

	// A minimal ERC20 ABI for balance and transfer
let ERC20ABI = """
[
	{
		"constant": true,
		"inputs": [
			{ "name": "_owner", "type": "address" }
		],
		"name": "balanceOf",
		"outputs": [
			{ "name": "balance", "type": "uint256" }
		],
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{ "name": "_to", "type": "address" },
			{ "name": "_value", "type": "uint256" }
		],
		"name": "transfer",
		"outputs": [
			{ "name": "", "type": "bool" }
		],
		"type": "function"
	}
]
"""
