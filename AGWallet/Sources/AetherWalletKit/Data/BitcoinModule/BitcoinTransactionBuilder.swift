//
//  BitcoinTransactionBuilder.swift
//  AGWallet
//
//  Raw legacy P2PKH transaction serialization and SIGHASH_ALL digest helper.
//

import Foundation
import CryptoKit
import SolanaSwift // provides public Base58.decode(_:) -> [UInt8]

struct BitcoinTxInput: Sendable {
	let txid: String
	let vout: UInt32
	let scriptSig: Data
	let sequence: UInt32
}

struct BitcoinTxOutput: Sendable {
	let valueSatoshis: Int64
	let scriptPubKey: Data
}

enum BitcoinScript {
	// Builds a standard P2PKH scriptPubKey (OP_DUP OP_HASH160 <hash160> OP_EQUALVERIFY OP_CHECKSIG)
	// from a Base58Check-encoded address.
	static func p2pkhScript(forAddress address: String) throws -> Data {
		let decodedBytes: [UInt8] = Base58.decode(address)
		guard decodedBytes.count >= 25 else {
			throw WalletError.signingFailed("Invalid Bitcoin address: \(address)")
		}
		let decoded = Data(decodedBytes)
		let hash160: Data = Data(decoded.dropFirst().dropLast(4)) // strip version byte + checksum
		var script: Data = Data([0x76, 0xa9, UInt8(hash160.count)]) // OP_DUP OP_HASH160 <len>
		script.append(hash160)
		script.append(Data([0x88, 0xac])) // OP_EQUALVERIFY OP_CHECKSIG
		return script
	}

	// Minimal DER encoding for a 64-byte raw (r||s) signature, enforcing low-S.
	static func derEncode(signature: Data) throws -> Data {
		guard signature.count == 64 else {
			throw WalletError.signingFailed("Unexpected signature length: \(signature.count)")
		}
		var r = Data(signature.prefix(32))
		var s = Data(signature.suffix(32))

		func trim(_ v: Data) -> Data {
			var bytes = Array(v)
			while bytes.count > 1 && bytes[0] == 0x00 && (bytes[1] & 0x80) == 0 {
				bytes.removeFirst()
			}
			if bytes[0] & 0x80 != 0 { bytes.insert(0x00, at: 0) }
			return Data(bytes)
		}
		r = trim(r)
		s = trim(s)

		var der = Data([0x02, UInt8(r.count)]) + r
		der.append(Data([0x02, UInt8(s.count)]) + s)
		return Data([0x30, UInt8(der.count)]) + der
	}

	static func pushData(_ data: Data) -> Data {
		precondition(data.count < 0x4c, "pushData only supports direct push opcodes (<76 bytes)")
		return Data([UInt8(data.count)]) + data
	}
}

enum BitcoinTransactionBuilder {
	private static let version: UInt32 = 1
	private static let locktime: UInt32 = 0

	// Serializes inputs/outputs into a raw legacy transaction hex-ready byte blob.
	static func serialize(inputs: [BitcoinTxInput], outputs: [BitcoinTxOutput]) -> Data {
		var data = Data()
		data.append(littleEndian(version))
		data.append(varInt(UInt64(inputs.count)))
		for input in inputs {
			data.append(reversedTxid(input.txid))
			data.append(littleEndian(input.vout))
			data.append(varInt(UInt64(input.scriptSig.count)))
			data.append(input.scriptSig)
			data.append(littleEndian(input.sequence))
		}
		data.append(varInt(UInt64(outputs.count)))
		for output in outputs {
			data.append(littleEndian(UInt64(bitPattern: output.valueSatoshis)))
			data.append(varInt(UInt64(output.scriptPubKey.count)))
			data.append(output.scriptPubKey)
		}
		data.append(littleEndian(locktime))
		return data
	}

	// Computes the SIGHASH_ALL double-SHA256 digest for signing a specific input,
	// substituting the given input's scriptSig with the previous output's scriptPubKey
	// and blanking all other inputs' scriptSigs, per BIP legacy sighash rules.
	static func sighashAll(
		inputs: [BitcoinTxInput],
		outputs: [BitcoinTxOutput],
		signingIndex: Int,
		prevScriptPubKey: Data
	) -> Data {
		let modifiedInputs = inputs.enumerated().map { index, input in
			BitcoinTxInput(
				txid: input.txid,
				vout: input.vout,
				scriptSig: index == signingIndex ? prevScriptPubKey : Data(),
				sequence: input.sequence
			)
		}
		var preimage = serialize(inputs: modifiedInputs, outputs: outputs)
		preimage.append(littleEndian(UInt32(1))) // SIGHASH_ALL
		return Data(SHA256.hash(data: Data(SHA256.hash(data: preimage))))
	}

	private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
		withUnsafeBytes(of: value.littleEndian) { Data($0) }
	}

	private static func varInt(_ value: UInt64) -> Data {
		switch value {
		case 0..<0xfd:
			return Data([UInt8(value)])
		case 0xfd..<0x10000:
			return Data([0xfd]) + littleEndian(UInt16(value))
		case 0x10000..<0x100000000:
			return Data([0xfe]) + littleEndian(UInt32(value))
		default:
			return Data([0xff]) + littleEndian(value)
		}
	}

	private static func reversedTxid(_ txid: String) -> Data {
		guard let bytes = Data(strictHex: txid) else { return Data(repeating: 0, count: 32) }
		return Data(bytes.reversed())
	}
}

private extension Data {
	init?(strictHex: String) {
		var data = Data()
		var hex = strictHex
		if hex.count % 2 != 0 { return nil }
		while !hex.isEmpty {
			let nextIndex = hex.index(hex.startIndex, offsetBy: 2)
			guard let byte = UInt8(hex[hex.startIndex..<nextIndex], radix: 16) else { return nil }
			data.append(byte)
			hex = String(hex[nextIndex...])
		}
		self = data
	}
}
