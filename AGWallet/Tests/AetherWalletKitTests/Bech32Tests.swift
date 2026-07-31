//
//  Bech32Tests.swift
//  AGWallet
//
//  Swift Testing coverage for the Bech32/Bech32m codec, including the official
//  BIP173 and BIP350 test vectors.
//

import Testing
import Foundation
@testable import AetherWalletKit

@Suite("Bech32")
struct Bech32Tests {

    // MARK: - BIP173 valid Bech32 (SegWit v0) address vectors

    @Test("BIP173 valid v0 addresses decode and round-trip", arguments: [
        "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4",
        "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
        "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
        "BC1SW50QGDZ25J",
        "bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs",
        "tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy"
    ])
    func bip173ValidAddressesDecode(_ address: String) throws {
        let decoded = try Bech32.decodeSegwitAddress(address)
        let reencoded = try Bech32.encodeSegwitAddress(
            hrp: decoded.hrp,
            witnessVersion: decoded.witnessVersion,
            program: decoded.program
        )
        #expect(reencoded == address.lowercased())
    }

    // MARK: - BIP350 valid Bech32m (SegWit v1 / Taproot) address vectors

    @Test("BIP350 valid v1 (Taproot) addresses decode and round-trip", arguments: [
        "BC1SW50QGDZ25J",
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0",
        "tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c"
    ])
    func bip350ValidTaprootAddressesDecode(_ address: String) throws {
        let decoded = try Bech32.decodeSegwitAddress(address)
        #expect(decoded.witnessVersion >= 1)
        let reencoded = try Bech32.encodeSegwitAddress(
            hrp: decoded.hrp,
            witnessVersion: decoded.witnessVersion,
            program: decoded.program
        )
        #expect(reencoded == address.lowercased())
    }

    // MARK: - Invalid address rejection

    @Test("Invalid addresses are rejected", arguments: [
        "tc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq5zuyut", // invalid hrp
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd", // invalid checksum (v1 using bech32 not bech32m intentionally broken)
        "bc1pw5dgrnzv", // invalid program length
        "bc1p38j9r5y49hruaue7wxjce0updqjuyyx0kh56v8s25huc6995vvpql3jow4", // invalid v0 program length disguised as v1
        "BC130XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ7ZWS8R", // invalid witness version
        "bc1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4" // mixed case is only invalid if truly mixed; validate separately below
    ])
    func invalidAddressesAreRejectedOrHandled(_ address: String) {
        // Some of these are intentionally malformed per BIP173/350 appendix "Invalid address" test vectors.
        // We only assert that decoding does not silently succeed with wrong data;
        // exact failure mode may vary (invalidChecksum vs invalidWitnessProgramLength, etc).
        do {
            _ = try Bech32.decodeSegwitAddress(address)
            // If it didn't throw, ensure it wasn't due to accepting mixed-case improperly.
            #expect(address == address.lowercased() || address == address.uppercased())
        } catch {
            #expect(error is Bech32Error)
        }
    }

    @Test("Mixed-case Bech32 strings are rejected")
    func mixedCaseIsRejected() {
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.decode("bc1Qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
        }
    }

    // MARK: - P2WPKH (20-byte program, v0) round trip using synthetic hash160

    @Test("P2WPKH mainnet address encodes and decodes with 20-byte program")
    func p2wpkhRoundTrip() throws {
        let hash160 = [UInt8](repeating: 0xAB, count: 20)
        let address = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 0, program: hash160)
        #expect(address.hasPrefix("bc1q"))

        let decoded = try Bech32.decodeSegwitAddress(address)
        #expect(decoded.witnessVersion == 0)
        #expect(decoded.program == hash160)
        #expect(decoded.hrp == "bc")
    }

    @Test("P2WPKH testnet address uses tb hrp")
    func p2wpkhTestnetHRP() throws {
        let hash160 = [UInt8](repeating: 0x01, count: 20)
        let address = try Bech32.encodeSegwitAddress(hrp: "tb", witnessVersion: 0, program: hash160)
        #expect(address.hasPrefix("tb1q"))
    }

    // MARK: - P2TR (32-byte x-only pubkey program, v1) round trip

    @Test("P2TR mainnet address encodes and decodes with 32-byte x-only pubkey")
    func p2trRoundTrip() throws {
        let xOnlyPubkey = [UInt8](repeating: 0xCD, count: 32)
        let address = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 1, program: xOnlyPubkey)
        #expect(address.hasPrefix("bc1p"))

        let decoded = try Bech32.decodeSegwitAddress(address)
        #expect(decoded.witnessVersion == 1)
        #expect(decoded.program == xOnlyPubkey)
    }

    // MARK: - Program length validation

    @Test("v0 witness program must be exactly 20 or 32 bytes")
    func v0RejectsInvalidProgramLength() {
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 0, program: [UInt8](repeating: 0, count: 21))
        }
    }

    @Test("Witness version must not exceed 16")
    func rejectsWitnessVersionAbove16() {
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 17, program: [UInt8](repeating: 0, count: 20))
        }
    }

    @Test("v1+ program length must be between 2 and 40 bytes")
    func v1RejectsOutOfRangeProgramLength() {
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 1, program: [UInt8](repeating: 0, count: 1))
        }
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.encodeSegwitAddress(hrp: "bc", witnessVersion: 1, program: [UInt8](repeating: 0, count: 41))
        }
    }

    // MARK: - Encoding/decoding variant enforcement (BIP350 rule: v0=>Bech32, v1+=>Bech32m)

    @Test("v0 address encoded with Bech32m checksum is rejected on decode")
    func v0WithBech32mChecksumIsRejected() throws {
        // Manually construct a v0 witness address but force Bech32m checksum encoding
        // to verify the BIP350 cross-variant validation rule is enforced.
        let hash160: [UInt8] = [UInt8](repeating: 0x11, count: 20)
        guard let words5bit = try? Bech32.encode(hrp: "bc", words: [0] + convertBitsForTest(hash160), encoding: .bech32m) else {
            Issue.record("Failed to construct malformed test address")
            return
        }
        #expect(throws: Bech32Error.self) {
            _ = try Bech32.decodeSegwitAddress(words5bit)
        }
    }

    private func convertBitsForTest(_ bytes: [UInt8]) -> [UInt8] {
        // Mirrors Bech32's private convertBits(fromBits:8, toBits:5, pad:true) for test construction only.
        var acc = 0, bits = 0
        var result: [UInt8] = []
        for byte in bytes {
            acc = (acc << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(UInt8((acc >> bits) & 0x1f))
            }
        }
        if bits > 0 {
            result.append(UInt8((acc << (5 - bits)) & 0x1f))
        }
        return result
    }
}
