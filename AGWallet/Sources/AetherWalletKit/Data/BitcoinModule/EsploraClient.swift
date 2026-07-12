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
	let scriptPubKeyHex: String

	enum CodingKeys: String, CodingKey {
		case txid
		case vout
		case value
		case scriptpubkey
	}

	init(outpoint: String, valueSatoshis: Int64, scriptPubKeyHex: String) {
		self.outpoint = outpoint
		self.valueSatoshis = valueSatoshis
		self.scriptPubKeyHex = scriptPubKeyHex
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let txid = try container.decode(String.self, forKey: .txid)
		let vout = try container.decode(Int.self, forKey: .vout)
		let value = try container.decode(Int64.self, forKey: .value)
		let script = try container.decodeIfPresent(String.self, forKey: .scriptpubkey) ?? ""

		self.outpoint = "\(txid):\(vout)"
		self.valueSatoshis = value
		self.scriptPubKeyHex = script
	}

	// Convenience accessors split from the combined outpoint string.
	var txid: String { String(outpoint.split(separator: ":")[0]) }
	var vout: UInt32 { UInt32(outpoint.split(separator: ":")[1]) ?? 0 }
}

struct BitcoinTxDraft: Sendable {
	let from: String
	let to: String
	let amountInSatoshis: Int64
	let utxos: [UTXO]
	let feeSatoshis: Int64
	let changeAddress: String

	init(
		from: String,
		to: String,
		amountInSatoshis: Int64,
		utxos: [UTXO],
		feeSatoshis: Int64 = 0,
		changeAddress: String? = nil
	) {
		self.from = from
		self.to = to
		self.amountInSatoshis = amountInSatoshis
		self.utxos = utxos
		self.feeSatoshis = feeSatoshis
		self.changeAddress = changeAddress ?? from
	}

	var totalInputSatoshis: Int64 { utxos.reduce(0) { $0 + $1.valueSatoshis } }
	var changeSatoshis: Int64 { totalInputSatoshis - amountInSatoshis - feeSatoshis }
}
