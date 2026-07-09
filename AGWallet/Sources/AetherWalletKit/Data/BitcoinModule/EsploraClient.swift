//
//  EsploraClient.swift
//  AGWallet
//
//  Created by Nicholas Reich on 7/9/26.
//


import Foundation

protocol EsploraClient: Sendable {
	func getUTXOs(for address: String) async throws -> [UTXO]
	func getTransactionHistory(for address: String) async throws -> [UnifiedTransaction]
	func broadcast(rawTransaction: String) async throws -> String
}

struct UTXO: Sendable, Decodable {
	let outpoint: String
	let valueSatoshis: Int64

	enum CodingKeys: String, CodingKey {
		case txid
		case vout
		case value
	}

	init(outpoint: String, valueSatoshis: Int64) {
		self.outpoint = outpoint
		self.valueSatoshis = valueSatoshis
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let txid = try container.decode(String.self, forKey: .txid)
		let vout = try container.decode(Int.self, forKey: .vout)
		let value = try container.decode(Int64.self, forKey: .value)

		self.outpoint = "\(txid):\(vout)"
		self.valueSatoshis = value
	}
}

struct BitcoinTxDraft: Sendable {
	let from: String
	let to: String
	let amountInSatoshis: Int64
	let utxos: [UTXO]
}
