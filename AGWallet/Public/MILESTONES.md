

## Work completed so far

### Architecture & domain

- `Domain/Models.swift` defines:
  - `ChainType`, `ChainNetwork`, `EndpointRole`, and `NetworkEndpointSet` for multi‑network, role‑based endpoints.[2]
  - `ChainConfig` with:
    - New initializer: `activeNetwork`, `networks: [ChainNetwork: NetworkEndpointSet]`.  
    - Legacy initializer: `rpcEndpoints` + optional `explorerUrl` for backwards compatibility.[2]
    - Helpers: `primaryEndpoint(for:)`, `endpoints(for:)`, `broadcastEndpoints`, `supportedNetworks`, `withActiveNetwork(_:)`.[2]
  - Core asset/transaction types:
    - `CryptoAsset` (name, symbol, decimals, optional `contractAddress`, `chainConfig`, `balance`).[3]
    - `BitcoinTransaction` + `BitcoinInput`/`BitcoinOutput`.  
      - `BitcoinInput` now includes `value` and `address` so Esplora data maps cleanly.[3]
    - `SolanaTransaction` + `SolanaInstruction`.  
    - `EVMTransaction` (hash, from/to, value, gasPrice, gasLimit, nonce, chainId, optional blockNumber, timestamp).[3]
    - `FlowArgument`, `FlowTransactionStatus`, `FlowTransaction`.[3]
    - `UnifiedTransaction` enum (`bitcoin`, `solana`, `evm`, `flow`) with a `date` accessor for sorting.[3]

- `Domain/SupportingTypes.swift` now contains:
  - `FlowTransactionTemplate` (script, `[FlowArgument]`, proposer, `[authorizers]`, payer, gasLimit).[2]
  - `ChainConfigurationError` (`chainAlreadyExists`, `chainNotFound`).[2]
  - `ChainModule` protocol with:
    - `getBalance(for asset: CryptoAsset) async throws -> Double`  
    - `send(amount: Double, to recipientAddress: String, for asset: CryptoAsset) async throws -> UnifiedTransaction`  
    - `getTransactionHistory(for chain: ChainConfig) async throws -> [UnifiedTransaction]`  
    - `signMessage(_ message: String, on chain: ChainConfig) async throws -> String`[2]

This gives you a stable domain contract for all modules and for `WalletCore`.

***

### EVM module

- `Data/EVMModule/EVMModule.swift` now:
  - Uses modern `Web3.new(rpcURL)` factory based on `chain.primaryEndpoint(for: .rpc)`.[2]
  - Implements `getBalance`:
    - Native: `web3.eth.getBalance(address:)` and divides by \(10^{18}\).[2]
    - ERC‑20: loads minimal `ERC20ABI`, calls `balanceOf`, and divides by \(10^{decimals}\).[2]
  - Implements `send(amount:to:for:)`:
    - Builds a `CodableTransaction` for native or token transfers.
    - Sets `from`, `chainID` from `ChainConfig.chainId` (validated as `Int`).[2]
    - Signs with private key data from `KeyManagerActor`.  
    - Encodes and submits via `web3.eth.send(raw:)`.[2]
    - Wraps the result in an `EVMTransaction` and returns `.evm(unifiedTx)`.[2]
  - Implements `signMessage` using:
    - `Utilities.hashPersonalMessage(messageData)` and `SECP256K1.signForRecovery`.[2]

Remaining work here is mainly enriching `EVMTransaction` (gas, nonce, block info) and adding real history via an indexer.

***

### Bitcoin module & Esplora client

- `Data/BitcoinModule/BitcoinModule.swift`:
  - Gets an Esplora client from `chain.primaryEndpoint(for: .rpc)` via `BitcoinEsploraClient` (with an injectable `esploraClientOverride` for testing).[4]
  - `getBalance`:
    - Fetches UTXOs and sums `value` to derive total balance in BTC (satoshis / 100_000_000).[4]
  - `send(amount:to:for:)`:
    - Prepares a `BitcoinTxDraft` from UTXOs, amount, a fixed fee (500 sats, TODO: dynamic fee estimation via Esplora), and change address.
    - `signTransaction` now delegates to `KeyManagerActor.signBitcoinTransaction`, which uses the new `BitcoinTransactionBuilder` (P2PKH scriptPubKey, DER signature encoding, SIGHASH_ALL digest) to produce a real raw signed transaction.
  - `getTransactionHistory`:
    - Delegates to `BitcoinEsploraClient.getTransactionHistory(for: address)` which maps Esplora JSON into `BitcoinTransaction` and wraps in `.bitcoin(...)`.[4][3]
  - `getAddress` now delegates to `KeyManagerActor.bitcoinAddress(for:)`; `signMessage` delegates to `KeyManagerActor` as well. Bitcoin address derivation, transaction signing, and message signing are all fully wired — no more `unsupportedOperation` stubs.[1]

- `Data/BitcoinModule/BitcoinEsploraClient.swift`:
  - Implements `getUTXOs(for:)` and `broadcast(rawTransaction:)` using Esplora HTTP endpoints.[4]
  - `getTransactionHistory(for address:)`:
    - Calls `/address/{address}/txs`.
    - Decodes `EsploraTransaction` and builds:
      - `BitcoinInput` from `vin` (txid, vout, value, prevout address).[3][4]
      - `BitcoinOutput` from `vout` (value, scriptpubkeyAddress).[4][3]
      - `BitcoinTransaction` with txid, fee, blockHeight, blockTime.[3][4]
    - Returns `[UnifiedTransaction]` via `.bitcoin(...)`.[4]

You now have a working Esplora integration with correct domain types, plus full Bitcoin signing and address derivation via `KeyManagerActor` and `BitcoinTransactionBuilder`; dynamic fee estimation remains a TODO.

***

### Solana module

- `Data/SolanaModule/SolanaModule.swift` now:
  - Uses `JSONRPCAPIClient` with `APIEndPoint(address: chain.primaryEndpoint(for: .rpc), network: .mainnetBeta)`.[4]
  - `getAddress`:
    - Derives public key from `KeyManagerActor.retrievePrivateKey(for: "masterKey")` and returns base58.[4]
  - `getBalance`:
    - Native SOL now calls `client.getBalance(account:commitment:)` and converts lamports to SOL; SPL token balances remain `unsupportedOperation`.
  - `getTransactionHistory`:
    - Now calls `client.getSignaturesForAddress` and `client.getTransaction` per signature, mapping results into `UnifiedTransaction.solana(...)` entries with real fee/slot/timestamp data; verified via `swift test` (25/25 passing).
  - `signMessage`:
    - You patched this to an `unsupportedOperation` stub, so it no longer attempts to call `Account.sign`. Build is green; Solana signing is clearly marked TODO.[1][4]

SPL token balance/history and Solana message signing are the next Solana steps.

***

### Flow module

- `Data/FlowModule/FlowModule.swift` exists and:
  - Logs Flow operations and throws `unsupportedOperation` for balance, send, and history.[5]
- `WalletCore.executeCadenceTransaction(_:)` is present but uses `FlowTransactionTemplate` and checks `flowModule`, throwing `unsupportedOperation("Flow module not enabled")` when missing.[5]

Flow is deliberately treated as experimental; you can choose to keep it gated or postpone full implementation.

***

### Key management

- `Data/KeyManagementModule/KeyManager.swift`:
  - Handles Secure Enclave setup and `SecKeyCreateWithData` with `WalletError.secureEnclaveError` on failure.[1]
  - Currently warns about an unused `privateKey` binding (but behaviour is correct); you can clean this up later by not binding the value.[1]
  - Exposes generic `retrievePrivateKey(for:)` and related helpers; chain‑specific signing helpers (Bitcoin/Solana) are not yet implemented, which is why the modules use `unsupportedOperation` stubs.[1]

***

### Repo and build status

- `git status` shows:
  - Modified: `BitcoinEsploraClient.swift`, `BitcoinModule.swift`, `KeyManager.swift`, `SolanaModule.swift`, `Domain/Models.swift`, `Domain/SupportingTypes.swift`.[1]
  - `.bak` files removed from dynamic configurator, key management, wallet core, etc.[1]
- `swift build` now completes successfully with only warnings (Secure Enclave `privateKey` and a Flow module unused binding).[1]

This is your baseline: multi‑chain domain, near‑complete EVM, partially wired Bitcoin/Solana, Secure Enclave key manager, and a compiling project.

***

## Remaining work & next steps (high level)

1. **KeyManagerActor chain‑specific APIs**
   - Add Bitcoin helpers: `bitcoinAddress(for:)`, `signBitcoinTransaction(_:chain:)`, `signBitcoinMessage(_:chain:)`.
   - Add Solana helpers: `solanaAddress(for:)`, `signSolanaMessage(_:chain:)`, `signSolanaTransfer(_:chain:)`.
   - Wire Bitcoin/Solana modules to these APIs instead of `unsupportedOperation` stubs.

2. **RPC enrichment**
   - EVM: fill `gasPrice`, `gasLimit`, `nonce`, and `blockNumber` in `EVMTransaction`; add real transaction history via indexer.
   - Bitcoin: confirm multi‑network support; consider indexer for transaction history beyond Esplora.
   - Solana: implement native SOL balance and SPL token balance; consider history support via an indexer.

3. **WalletCore API & tests**
   - Audit public `WalletCore` methods; add high‑level conveniences.
   - Add unit tests for domain types, modules, and `WalletCore`.

4. **CI/CD and app integration**
   - Add `swift build`/`swift test` GitHub Actions workflow.
   - Integrate AGWallet into `Aether.xcworkspace` and wire UI flows.

***

## Proposed `MILESTONES.md` (full file content)

You asked for a professional, tailored milestone file with bash for each step and complete content. Here is a ready‑to‑use `MILESTONES.md` you can create in `/Users/nicreich/AetherAG-mono/AGWallet`:

```markdown
# Aether Wallet – Production Milestones

This document tracks the major engineering milestones required to take the Aether wallet core (AGWallet) from the current state into a production‑ready SDK and app.

Workspace: `/Users/nicreich/AetherAG-mono/AGWallet` (repo: `https://github.com/13Ophiuchus/AetherAG-mono.git`).

---

## 0. Current Baseline

**Architecture & domain**

- Multi‑network `ChainConfig` implemented with:
  - `ChainType`, `ChainNetwork`, `EndpointRole`, `NetworkEndpointSet`.
  - Role‑based endpoints via `primaryEndpoint(for:)` and `endpoints(for:)`.
  - Legacy `rpcEndpoints` initializer preserved for backwards compatibility.  
- Core models implemented:
  - `CryptoAsset`, per‑chain transaction structs (`BitcoinTransaction`, `EVMTransaction`, `SolanaTransaction`, `FlowTransaction`).
  - `BitcoinInput`/`BitcoinOutput` aligned with Esplora JSON.
  - `UnifiedTransaction` enum with `date` accessor.
- `ChainModule` protocol defined, covering balance, send, history, and message signing.

**Modules**

- **EVMModule**: native + ERC‑20 balance, send, and `signMessage` implemented using `web3swift` and `SECP256K1`.
- **BitcoinModule + BitcoinEsploraClient**: UTXO lookup and transaction history via Esplora; signing and address derivation clearly marked as TODO.
- **SolanaModule**: RPC wiring in place; address derivation, native SOL balance, and transaction history implemented; SPL token balance/history and message signing still stubbed with `unsupportedOperation`.
- **FlowModule**: present but explicitly treated as experimental (unsupported operations).

**Key management**

- `KeyManagerActor` handles Secure Enclave key creation and retrieval.
- Generic `retrievePrivateKey(for:)` APIs available; chain‑specific helpers not yet implemented.

**Build status**

- `swift build` completes successfully (warnings only).

Baseline commands:

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet
swift build
swift test   # once tests are added
```

---

## 1. Domain & Configuration Stabilisation

**Goals**

Lock down the domain model and configuration as the stable public contract for all chain modules and `WalletCore`.

**Tasks**

- [x] Implement `ChainType`, `ChainNetwork`, `EndpointRole`, `NetworkEndpointSet`, and `ChainConfig` with role‑based endpoints.
- [x] Add `activeNetwork` plus `withActiveNetwork(_:)` for network switching.
- [x] Implement `CryptoAsset` and per‑chain transaction types.
- [x] Implement `UnifiedTransaction` and convenience `date` accessor.
- [ ] Review access levels (`public` vs `internal`) for all domain types.
- [ ] Add documentation comments to all public domain types.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Inspect domain models
sed -n '1,260p' Sources/AetherWalletKit/Domain/Models.swift

# Quick build to validate changes
swift build
```

---

## 2. Chain Module Parity & RPC Reliability

### 2.1 EVMModule

**Goals**

Bring EVM support to full production quality.

**Tasks**

- [x] Implement `getBalance` for native ETH and ERC‑20 tokens.
- [x] Implement `send` using `CodableTransaction` and `Web3.new(rpcURL)`.
- [x] Implement `signMessage` via `hashPersonalMessage` and `SECP256K1`.
- [x] Populate `gasPrice`, `gasLimit`, and `nonce` fields in `EVMTransaction` using RPC:
  - `web3.eth.gasPrice()`, `web3.eth.estimateGas(for:)`, `web3.eth.getTransactionCount(for:onBlock:)` wired into `EVMModule.send(amount:to:for:)`; verified via `swift test` (23/23 passing).
- [ ] Implement real `getTransactionHistory` via an indexer (e.g. Etherscan or custom service).

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Edit EVM module
nano Sources/AetherWalletKit/Data/EVMModule/EVMModule.swift

# Build and test
swift build
swift test
```

---

### 2.2 BitcoinModule & EsploraClient

**Goals**

Stabilise Bitcoin RPC behaviour and integrate proper signing.

**Tasks**

- [x] Wire `BitcoinModule` to Esplora via `BitcoinEsploraClient` using `ChainConfig.primaryEndpoint(for: .rpc)`.
- [x] Implement `getUTXOs(for:)` and `getTransactionHistory(for:)` mapping to `BitcoinTransaction`.
- [x] Ensure `BitcoinInput` and `BitcoinOutput` domain structs match Esplora JSON fields.
- [x] Replace `unsupportedOperation` stubs with real `KeyManagerActor` calls:
  - `bitcoinAddress(for:)`
  - `signBitcoinTransaction(_:chain:)`
  - `signBitcoinMessage(_:chain:)`
- [ ] Confirm multi‑network support (mainnet, signet, regtest) via `ChainNetwork` and `ChainConfig.networks`.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Inspect Bitcoin module and client
sed -n '1,200p' Sources/AetherWalletKit/Data/BitcoinModule/BitcoinModule.swift
sed -n '30,120p' Sources/AetherWalletKit/Data/BitcoinModule/BitcoinEsploraClient.swift

swift build
```

---

### 2.3 SolanaModule

**Goals**

Implement reliable Solana RPC flows and signing.

**Tasks**

- [x] Implement `rpcClient(for:)` with `JSONRPCAPIClient` using `ChainConfig.primaryEndpoint(for: .rpc)`.
- [x] Implement `getAddress` via public key derived from `KeyManagerActor`.
- [ ] Implement native SOL balance via `getBalance(account:)`.
- [ ] Implement SPL token balance when `CryptoAsset.contractAddress` is set.
- [x] Stub `getTransactionHistory` with `unsupportedOperation` until indexer is chosen.
- [x] Stub `signMessage` with `unsupportedOperation` until `KeyManagerActor` signing helpers are added.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Edit Solana module
nano Sources/AetherWalletKit/Data/SolanaModule/SolanaModule.swift

swift build
```

---

### 2.4 FlowModule

**Goals**

Decide Flow support scope and treat it appropriately.

**Tasks**

- [x] Keep Flow module present but clearly marked as experimental (unsupported operations).
- [x] Decide whether Flow is in scope for v1.0: yes — Flow is in scope; implementing balance, send, and history using current Flow SDK.
  - [x] Implement `getBalance` via a real Cadence script borrowing `FlowToken.Vault`'s public balance capability (`GetFlowBalanceQuery` in FlowModule.swift).
  - [x] Implement `signMessage` via ECDSA_P256 signing against the stored master key (`signFlowMessage` in KeyManager.swift).
  - [ ] Implement `send` (requires a `FlowSigner` bridge from `KeyManagerActor` to the Flow SDK's signer protocol).
  - [ ] Implement `getTransactionHistory` (requires an indexer integration; no native indexer in flow-swift-macos).

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Inspect Flow module
sed -n '1,200p' Sources/AetherWalletKit/Data/FlowModule/FlowModule.swift

swift build
```

---

## 3. Key Management & Signing Hardening

**Goals**

Centralise all chain‑specific signing and address derivation in `KeyManagerActor`.

**Tasks**

- [x] Implement Secure Enclave key creation and retrieval using `SecKeyCreateWithData`.
- [x] Surface Secure Enclave errors via `WalletError.secureEnclaveError`.
- [x] Add chain‑specific helpers:
  - Bitcoin: `bitcoinAddress(for:)`, `signBitcoinTransaction(_:chain:)`, `signBitcoinMessage(_:chain:)`.
  - Solana: `solanaAddress(for:)`, `signSolanaMessage(_:chain:)`, `signSolanaTransfer(_:chain:)`.
- [x] Replace `unsupportedOperation` stubs in `BitcoinModule` and `SolanaModule` with calls to these helpers.
- [x] Add unit tests for key derivation and signing per chain and network.
- [x] Resolve secp256k1 package graph conflict ("secp256k1.swift" vs "swift-secp256k1" libsecp256k1 duplicate target) by repointing web3swift and solana-swift to local patched copies and importing "libsecp256k1" alongside "P256K" in SECP256k1.swift and CKSecp256k1.swift. All 22 tests across 5 suites (SolanaModule, EVMModule, BitcoinModule, FlowModule, KeyManagerActor Solana signing) now pass with "swift build" / "swift test" clean.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Edit key manager
nano Sources/AetherWalletKit/Data/KeyManagementModule/KeyManager.swift

swift build
swift test
```

---

## 4. WalletCore Orchestration & Public API

**Goals**

Make `WalletCore` the single, stable façade over all chain modules and key management.

**Tasks**

- [x] Maintain `WalletCore.swift` as the orchestrator tying `ChainModule`s and `KeyManagerActor` together.
- [x] Audit all public methods for clear naming and consistent error handling (getBalance, send, getTransactionHistory, signMessage all use consistent switch-dispatch + WalletError.unsupportedOperation pattern; fixed unused flowModule binding in executeCadenceTransaction).
- [x] Ensure only supported chains are exposed in the public API: Flow is gated via the "enableFlow" init parameter on WalletCore (default true, can be disabled by consumers); all Flow operations explicitly throw WalletError.unsupportedOperation until implemented, so no silent partial functionality is exposed.
- [x] Add documentation comments to getBalance, send, getTransactionHistory, and signMessage.
- [x] Introduce high‑level convenience methods (already present under clear names matching the ChainModule protocol contract):
  - `balance(for asset:)`
  - `send(asset:to:amount:)`
  - `history(for chain:)`

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Inspect WalletCore
sed -n '1,260p' Sources/AetherWalletKit/WalletCore.swift

swift build
swift test
```

---

## 5. Testing, QA, and CI/CD

**Goals**

Ensure regressions are caught early and the core is continuously validated.

**Tasks**

- [x] Add unit tests for:
  - `ChainConfig` and endpoint resolution.
  - `CryptoAsset` and transaction types.
  - EVM/Bitcoin/Solana/Flow module behaviour (using mock RPC clients and an in-memory `InMemoryKeyStorageProvider` to avoid Keychain entitlement issues in unsigned test binaries).
  - `KeyManagerActor` key generation and signing.
- [ ] Add integration tests around `WalletCore`.
- [ ] Set up CI (e.g. GitHub Actions) to run `swift build` and `swift test` on `main` and PR branches.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Run tests locally
swift test

# Bootstrap CI workflow (example)
mkdir -p .github/workflows
nano .github/workflows/swift.yml
```

---

## 6. App Integration & UX

**Goals**

Wire AGWallet into the client apps and provide a usable UX.

**Tasks**

- [ ] Add AGWallet as a package or local project to `Aether.xcworkspace`.
- [ ] Implement flows for:
  - Wallet creation / restore.
  - Multi‑chain balance overview.
  - Chain‑specific send flows.
  - Transaction history display.
- [ ] Ensure `WalletError` messages are surfaced cleanly in the UI.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono

# Open the workspace
open Aether.xcworkspace
```

---

## 7. Security Review, Observability, and Release

**Goals**

Validate security posture and prepare for production release.

**Tasks**

- [ ] Review key management and signing paths with a security‑focused checklist.
- [ ] Ensure all RPC endpoints are HTTPS and configured per environment via `ChainConfig`.
- [ ] Add structured logging and basic telemetry in critical paths.
- [ ] Tag v1.0 and prepare release notes.

**Commands**

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet

# Final build & tests
swift build
swift test

# Tag and push a release
git tag -a v1.0.0 -m "Aether Wallet SDK v1.0.0"
git push origin v1.0.0
```

---

## Summary

From the current baseline — multi‑chain domain, robust EVM support, partially wired Bitcoin and Solana, and a Secure Enclave key manager — the path to production is mainly about:

- Implementing chain‑specific signing and address derivation in `KeyManagerActor`.
- Replacing module stubs with real Bitcoin/Solana/Flow flows.
- Hardening `WalletCore` and adding tests + CI.
- Integrating into the app and completing a security/observability pass.

Track each of these tasks in `MILESTONES.md` and update the checkboxes as you progress toward a production‑ready Aether wallet core.

Sources
[2] pasted_text_1783610364.txt https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/80463257/5769cfe4-cc44-4545-8ee0-472776f12c53/pasted_text_1783610364.txt?AWSAccessKeyId=ASIA2F3EMEYE3H4ZRQW6&Signature=VYdIAGarDfacc0AOoRWfkzmq2Nc%3D&x-amz-security-token=IQoJb3JpZ2luX2VjENr%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIBvDYEZoHfWu2PdfUsyyUlNN1QkChfXwG7J7nNybJZdNAiEAzH9MCm7GsvIJfGR0PCVe2Zil%2F%2F7lo7%2BNRkNg0htzo%2FUq%2FAQIo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDCVCPkIXx2YA6RHlRyrQBDMtOcLakY04kZCiH6yQUI%2BmsxDJXDC0MznxFjsqI3skQtcLXXpzrJGZk8Y07YrzRFRi%2FkuDf3tc0OebGHxJWR%2F1SPdDXt%2F8%2BWTezvNFR%2BT3hDJux1PKEcRaW4KGBYaDzsT8B%2FOzKfNTzizUYvo0Jq%2FllwDFNWLBiR4nAPY3IrZIUywRclM5W3i9k8IuCygjoPHj5TzS4GfiY%2BDmhDWitWbLM3c8QMNxYvO7cbTljUkn0sHyZhyc67Ho8wAymhDTAgKxNQLxSLKpc4WMGl8E6VAA2pgLvgJi23ju3uNuhIQi81dVYcPP9oYqrd4VBX%2F1tD4%2F0l9G8YEtVe09hSkGrQmQhWhdT3z7HhXB6ESDDCq1zaExYwFXxyj5NrhSOeNxiMqmMfmecOiam8747gu3eLHnHF5%2FsRAKUS6cK7OhqxJP8m12h4euxzd6Ol3t61d0HeStXOelvxMYcPR5N4DIa8Jkl8%2BsdirH2jYVVqRBE49HxXPOG5kRCYrGHZRqiRdxNAkrItOkduhzSV0TVhJfVznz7zi5DNdMyL8aUJOPpRMkDlfmKSTVHST9n0l%2FaedOyxa6GsG4xut%2BaOOYtsR5f2Hj%2Fgp9ZcRec8TNnTNgWMReAj2opcChztmnGFrRSlWR5T4VZjAtLstULYkCQII9EmqmhSyHumnz0pZQJadAANYFIJDGHT4ZKH86tyzlKHq1F1mUKzWVZ7JHi5xybCloYIen%2F%2FY6j%2Bud%2FeMlf4ZCISgJErg8aUQS7%2FiArsYT%2F2FrRCIPXSQr76oEBOHhKnohK%2BQw2sG%2F0gY6mAFugf9FmecUYdObDTdZkcCbm67w%2F%2B6EwI5cK5DorSzYrf3hePR5dnazOtlhAuBAehclfWkDTu4pmlGHbuXoxrBmMcid45yBKHDUauhxGku8w%2BURC9apE%2FFJE%2FNlrdFrZ9bva1InlSIZTJ7RN1Ln%2Fo9PcJ15rVaD6kdaItcZoxAF3uzxXFTr3kTUczHbYHH%2BwQnt9%2FPbtsyMug%3D%3D&Expires=1783623341
