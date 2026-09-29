# AetherAG-mono / AGWallet — Project State Report
**Generated:** 2026-09-29 01:29 EDT

## Summary

AGWallet is a multi-chain Swift wallet SDK (EVM, Solana, Bitcoin, Flow) built
on a single master-key architecture via `KeyManagerActor`, with per-chain
address derivation and Keychain/Secure Enclave-backed key storage. This report
captures the state after resolving the FlowModule build failures and
implementing real Flow account creation.

## What was fixed this session

1. **FlowModule build errors resolved** — missing `FlowIssuerConfig` type,
   missing gateway abstraction, hex decoding, `Any` type inference, event
   field access, and duplicate declarations from a bad merge.
2. **Key security hardened** — issuer private key now loads from Keychain by
   reference at sign time only, never held as a plaintext hex string in
   `FlowIssuerConfig`.
3. **Transaction seal-polling improved** — replaced a fixed 2-second polling
   loop with exponential backoff (500ms → 8s cap) and a 90-second deadline.
4. **`createFlowAccount` fully implemented** — initially scaffolded behind a
   `FlowGatewayProtocol` abstraction with a `fatalError()` placeholder for
   transaction submission. That abstraction was **removed entirely** and
   replaced with a direct `CreateFlowUserAccountTarget: CadenceTargetType`
   struct, using the exact same `flowClient.sendTransaction(target,
   signers:, chainID:)` path already proven in production by `send()`.
5. **Repo hygiene** — removed accumulating `.bak` files (now gitignored),
   removed one-off debug scripts, moved a 4.1GB stray backup directory out of
   the repo, bumped `web3swift-concurrency` (Linux-portability fixes) and
   `AetherAG` (Swift 6 migration) submodule pointers.

## Current build/test health

- Build warnings: **0**
- Test result: `104 tests in 21 suites`
- TODO/FIXME markers remaining: **1**
- `fatalError()` calls remaining in Sources/: **1**
- Working tree: Clean — no uncommitted changes.

## Module file counts

- EVMModule: 2 files
- FlowModule: 3 files
- SolanaModule: 1 files
- BitcoinModule: 8 files
- KeyManagementModule: 4 files

## Submodule sync state

```
 8a7ba223148128dc82fe0736152d6321cc3cc14c AetherAG (swift-6.4-migration-verified-9-g8a7ba22)
 f6ebc4313f2e93d84e53dbd478088761b3b6e1bb flow-swift-macos (v0.1.0-linux-patch-4-gf6ebc43)
 d30b8631fb40aaa08cfb065b64abf36057852c78 solana-swift-concurrency (solana-tests-passing-3-gd30b8631)
 a377b32a9f69c028464349131657b8e07711e9c6 web3swift-concurrency (3.0.0-721-ga377b32a)
```

## Known naming collision (not a bug, just worth remembering)

There are **two unrelated** `FlowGatewayProtocol` types in this mono-repo:
- `AGWallet`'s version was removed this session (replaced by direct
  `CadenceTargetType` usage).
- `AetherAG/Sources/AetherAGMailServer/Flow/FlowGatewayProtocol.swift` is a
  **separate, legitimate** protocol for the mail server's Flow key-rotation
  service. Do not confuse the two if grepping for this name in the future.

## What is still needed

1. **Live testnet validation** — `createFlowAccount` compiles and passes
   unit tests, but has never executed against real Flow testnet
   infrastructure. Run the gated integration test:
   ```
   FLOW_TESTNET_INTEGRATION=1 FLOW_TESTNET_ISSUER_KEY=<funded-testnet-key> swift test --filter FlowAccountCreation
   ```
2. **Gas limit review** — the new `CreateFlowUserAccountTarget` path relies
   on `sendTransaction`'s default gas limit (9999) rather than the
   previously hardcoded 200. This is safe (higher ceiling, same cost model)
   but worth confirming against your funding budget per account creation.
3. **Hex-string audit doc close-out** — `docs/Wallet_Account_Key_Audit.md`
   was updated to note the gap closure; confirm no other stale findings
   remain in that document.
4. **Remaining TODO/FIXME markers** (1 found) — review and triage;
   see full list above.
5. **Dev script archive** — `configflow.py`, `diagnose_swift_toolchain.sh`,
   `diagnose_toolchain.sh`, `swiftly.sh` were removed from the repo and
   archived to `~/dev-scripts-archive/`. Confirm none of them are still
   needed as permanent CI/dev tooling before considering that closed.

