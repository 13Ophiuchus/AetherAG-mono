//
//  FlowIssuerConfig.swift
//  AetherWalletKit
//
//  Created by Nicholas Reich on 9/28/26.
//


#!/usr/bin/env python3
"""
patch_flow_module.py
Fixes FlowModule.swift:
  1. Removes the duplicated "Flow Account Creation & Reset" block.
  2. Rewrites createFlowAccount to use new FlowIssuerSigner instead of the
     nonexistent FlowAccountService.makeSigner().
  3. Adds explicit [Flow.Argument] typing to fix the .string/.uint8/.ufix64
     "Type 'Any'" errors.
Creates two new sibling files:
  - FlowIssuerConfig.swift
  - FlowGatewayProtocol.swift (protocol + LiveFlowGateway + FlowIssuerSigner)
"""

import re
from pathlib import Path

MODULE_DIR = Path("Sources/AetherWalletKit/Data/FlowModule")
MODULE_FILE = MODULE_DIR / "FlowModule.swift"
MARKER = "// MARK: - Flow Account Creation & Reset (appended)"

text = MODULE_FILE.read_text()

occurrences = [m.start() for m in re.finditer(re.escape(MARKER), text)]
if len(occurrences) != 2:
    raise SystemExit(f"Expected 2 occurrences of marker, found {len(occurrences)}. Aborting — inspect manually.")

first_start, second_start = occurrences
deduped = text[:second_start].rstrip() + "\n"

old_create_pattern = re.compile(
    r'public func createFlowAccount\(.*?\n    \}\n',
    re.DOTALL
)

new_create_fn = '''public func createFlowAccount(
        issuerConfig: FlowIssuerConfig,
        flowGateway: any FlowGatewayProtocol,
        network: Flow.ChainID,
        keyIdentifier: String = "masterKey"
    ) async throws -> String {
        let publicKeyHex = try flowP256PublicKeyHex(keyIdentifier: keyIdentifier)
        let signer = FlowIssuerSigner(issuerConfig: issuerConfig)

        guard let scriptURL = Bundle.module.url(
            forResource: "create_user_account",
            withExtension: "cdc",
            subdirectory: "Cadence"
        ) else {
            throw WalletError.chainConfigurationError("Missing create_user_account.cdc resource")
        }
        let script = try Data(contentsOf: scriptURL)

        let arguments: [Flow.Argument] = [
            Flow.Argument(value: .string(publicKeyHex)),
            Flow.Argument(value: .uint8(1)),
            Flow.Argument(value: .uint8(3)),
            Flow.Argument(value: .ufix64(Decimal(string: "1000.0") ?? 1000))
        ]

        let txID = try await flowGateway.sendTransaction(
            script: script,
            arguments: arguments,
            gasLimit: 200,
            proposalKey: issuerConfig.proposalKey,
            payer: issuerConfig.address,
            authorizers: [issuerConfig.address],
            envelopeSigner: signer
        )

        var result = try await flowGateway.transactionResult(id: txID)
        for _ in 0..<30 {
            if result.status == .sealed { break }
            try await Task.sleep(nanoseconds: 2_000_000_000)
            result = try await flowGateway.transactionResult(id: txID)
        }

        guard result.status == .sealed else {
            throw WalletError.signingFailed("Flow account creation did not seal in time")
        }
        guard let event = result.events.first(where: { $0.type.contains("AccountCreated") }),
              let newAddressHex = event.payload["address"] as? String else {
            throw WalletError.signingFailed("Account creation sealed but no AccountCreated event found")
        }

        try storeFlowAddress(newAddressHex)
        return newAddressHex
    }
'''

patched, count = old_create_pattern.subn(new_create_fn, deduped)
if count != 1:
    raise SystemExit(f"Expected to replace exactly 1 createFlowAccount body, replaced {count}. Aborting.")

MODULE_FILE.write_text(patched)
print(f"Patched {MODULE_FILE}: removed duplicate block, rewrote createFlowAccount.")

issuer_config_swift = '''import Flow
import Foundation

/// Configuration for the issuer/payer account that funds and authorizes
/// creation of new Flow accounts on behalf of this wallet.
///
/// - Warning: `privateKeyHex` holds raw signing key material. In production
///   load this from a secure secrets store (server-side KMS/HSM); never
///   bundle it in the app binary or commit it to source control.
public struct FlowIssuerConfig: Sendable {
    public let address: Flow.Address
    public let keyIndex: Int
    public let privateKeyHex: String
    public let proposalKey: Flow.TransactionProposalKey

    public init(
        address: Flow.Address,
        keyIndex: Int,
        privateKeyHex: String,
        proposalKey: Flow.TransactionProposalKey
    ) {
        self.address = address
        self.keyIndex = keyIndex
        self.privateKeyHex = privateKeyHex
        self.proposalKey = proposalKey
    }
}
'''
(MODULE_DIR / "FlowIssuerConfig.swift").write_text(issuer_config_swift)
print("Created FlowIssuerConfig.swift")

gateway_swift = '''import Flow
import CryptoKit
import Foundation

/// Abstraction over the Flow access-node gateway used for account creation,
/// allowing production code to talk to a live access node while unit tests
/// substitute a mock implementation.
public protocol FlowGatewayProtocol: Sendable {
    func sendTransaction(
        script: Data,
        arguments: [Flow.Argument],
        gasLimit: UInt64,
        proposalKey: Flow.TransactionProposalKey,
        payer: Flow.Address,
        authorizers: [Flow.Address],
        envelopeSigner: any FlowSigner
    ) async throws -> Flow.ID

    func transactionResult(id: Flow.ID) async throws -> Flow.TransactionResult
}

/// Production implementation of `FlowGatewayProtocol` backed by the live
/// Flow access API.
///
/// - Important: The exact builder syntax below (`cadence`, `proposer`,
///   `payer`, `authorizers`, `gasLimit`) must match your installed Flow
///   Swift SDK's transaction-building API. Verify against your checked-out
///   package version before relying on this in production — see the grep
///   command in the accompanying bash script.
public final class LiveFlowGateway: FlowGatewayProtocol {
    private let flowClient: Flow
    private let chainID: Flow.ChainID

    public init(chainID: Flow.ChainID) {
        self.chainID = chainID
        self.flowClient = Flow()
    }

    public func sendTransaction(
        script: Data,
        arguments: [Flow.Argument],
        gasLimit: UInt64,
        proposalKey: Flow.TransactionProposalKey,
        payer: Flow.Address,
        authorizers: [Flow.Address],
        envelopeSigner: any FlowSigner
    ) async throws -> Flow.ID {
        // TODO: Confirm this matches your Flow SDK's actual transaction
        // builder API (result-builder DSL vs explicit Flow.Transaction init).
        fatalError("Implement against your installed Flow SDK's transaction builder API")
    }

    public func transactionResult(id: Flow.ID) async throws -> Flow.TransactionResult {
        try await flowClient.accessAPI.getTransactionResultById(id: id)
    }
}

/// Signs Flow transaction envelopes on behalf of an issuer/payer account
/// using a raw hex-encoded P256 private key.
///
/// - Important: Assumes ECDSA_P256 + SHA2_256, matching this wallet's own
///   key derivation. Adapt if your issuer account uses a different curve.
struct FlowIssuerSigner: FlowSigner {
    let issuerConfig: FlowIssuerConfig

    var address: Flow.Address { issuerConfig.address }
    var keyIndex: Int { issuerConfig.keyIndex }

    func sign(signableData: Data, transaction: Flow.Transaction?) async throws -> Data {
        guard let keyData = Data(hexString: issuerConfig.privateKeyHex) else {
            throw WalletError.signingFailed("Invalid issuer private key hex")
        }
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        let digest = SHA256.hash(data: signableData)
        let signature = try signingKey.signature(for: digest)
        return signature.rawRepresentation
    }
}
'''
(MODULE_DIR / "FlowGatewayProtocol.swift").write_text(gateway_swift)
print("Created FlowGatewayProtocol.swift")
