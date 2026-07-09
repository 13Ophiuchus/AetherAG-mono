//
//  BitcoinEsploraClient.swift
//  AGWallet
//
//  Created by Nicholas Reich on 7/9/26.
//


import Foundation

final class BitcoinEsploraClient: EsploraClient, @unchecked Sendable {
	private let baseURL: URL
	private let session: URLSession
	private let logger = Logger(label: "AetherWalletKit.BitcoinEsploraClient")

	init(
		baseURL: URL,
		session: URLSession = .shared
	) {
		self.baseURL = baseURL
		self.session = session
	}

	func getUTXOs(for address: String) async throws -> [UTXO] {
		let url = baseURL
			.appendingPathComponent("address")
			.appendingPathComponent(address)
			.appendingPathComponent("utxo")

		let (data, response) = try await session.data(from: url)
		try validate(response, data: data)

		return try JSONDecoder().decode([UTXO].self, from: data)
	}

	func getTransactionHistory(for address: String) async throws -> [UnifiedTransaction] {
		let url = baseURL
			.appendingPathComponent("address")
			.appendingPathComponent(address)
			.appendingPathComponent("txs")

		let (data, response) = try await session.data(from: url)
		try validate(response, data: data)

		let transactions = try JSONDecoder().decode([EsploraTransaction].self, from: data)

		return transactions.map { tx in
			let inputs = tx.vin.map { vin in
				BitcoinInput(
					previousTxId: vin.txid ?? "",
					outputIndex: vin.vout ?? 0,
					value: Double(vin.prevout?.value ?? 0) / 100_000_000,
					address: vin.prevout?.scriptpubkeyAddress ?? ""
				)
			}

			let outputs = tx.vout.map { vout in
				BitcoinOutput(
					value: Double(vout.value) / 100_000_000,
					address: vout.scriptpubkeyAddress ?? ""
				)
			}

			return .bitcoin(
				BitcoinTransaction(
					txId: tx.txid,
					inputs: inputs,
					outputs: outputs,
					fee: Double(tx.fee) / 100_000_000,
					blockHeight: tx.status.blockHeight,
					timestamp: tx.status.blockTime.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
				)
			)
		}
	}

	func broadcast(rawTransaction: String) async throws -> String {
		let url = baseURL.appendingPathComponent("tx")

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = rawTransaction.data(using: .utf8)
		request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

		let (data, response) = try await session.data(for: request)
		try validate(response, data: data)

		guard let txId = String(data: data, encoding: .utf8)?
			.trimmingCharacters(in: .whitespacesAndNewlines),
			  !txId.isEmpty else {
			throw WalletError.chainConfigurationError("Esplora returned an empty transaction ID")
		}

		logger.info("Broadcasted Bitcoin transaction: \(txId)")
		return txId
	}

	private func validate(_ response: URLResponse, data: Data) throws {
		guard let httpResponse = response as? HTTPURLResponse else {
			throw WalletError.chainConfigurationError("Invalid Esplora response")
		}

		guard (200...299).contains(httpResponse.statusCode) else {
			let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
			throw WalletError.chainConfigurationError("Esplora request failed (\(httpResponse.statusCode)): \(responseBody)")
		}
	}
}

private struct EsploraTransaction: Decodable {
	let txid: String
	let fee: Int64
	let status: Status
	let vin: [Vin]
	let vout: [Vout]

	struct Status: Decodable {
		let confirmed: Bool
		let blockHeight: Int?
		let blockTime: Int?

		enum CodingKeys: String, CodingKey {
			case confirmed
			case blockHeight = "block_height"
			case blockTime = "block_time"
		}
	}

	struct Vin: Decodable {
		let txid: String?
		let vout: Int?
		let prevout: Prevout?
	}

	struct Prevout: Decodable {
		let value: Int64
		let scriptpubkeyAddress: String?

		enum CodingKeys: String, CodingKey {
			case value
			case scriptpubkeyAddress = "scriptpubkey_address"
		}
	}

	struct Vout: Decodable {
		let value: Int64
		let scriptpubkey: String
		let scriptpubkeyAddress: String?

		enum CodingKeys: String, CodingKey {
			case value
			case scriptpubkey
			case scriptpubkeyAddress = "scriptpubkey_address"
		}
	}
}

private extension Data {
	init(hex: String) {
		let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		var data = Data()
		var index = clean.startIndex

		while index < clean.endIndex {
			let nextIndex = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
			let byteString = clean[index..<nextIndex]
			if let byte = UInt8(byteString, radix: 16) {
				data.append(byte)
			}
			index = nextIndex
		}

		self = data
	}
}
