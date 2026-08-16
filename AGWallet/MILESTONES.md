## Milestone 19: Flow Token Transfer Signing Bridge (2026-08-15)

- [x] `FlowModule.send` rewritten using real `CadenceTargetType` + `FlowSigner` API instead of placeholder/stub
- [x] `TransferFlowTokenTarget` — `CadenceTargetType` conformance for plain FlowToken transfers (cadenceBase64 script, ufix64/address arguments)
- [x] `KeyManagerFlowSigner` — bridges `FlowSigner` protocol to `KeyManagerActor.signFlowTransactionEnvelope`, keeping raw key material inside the actor boundary
- [x] Fixed invalid redeclaration bug — duplicate `TransferFlowTokenTarget` block (introduced by a non-idempotent append-only patch script) removed; only one definition remains
- [x] AGWallet build clean under Swift 6.3 / arm64-apple-macosx26.0 (70/70 targets, FlowModule.swift + AetherWalletKit module emission)

## Milestone 18: getReceiveAddress across all chains (2026-08-15)

- [x] `FlowModule.getReceiveAddress` — restored guard with `try await keyManager.flowAddress()`; removed orphaned throw/return lines outside guard scope
- [x] `EVMModule.getReceiveAddress` — added using existing `getEthereumAddress` private helper; returns `EthereumAddress.address` string
- [x] `WalletCore.getReceiveAddress` — rewritten inside actor; all four chain arms wired; `ChainConfigurationService.getPredefinedChains()` called with `await`
- [x] `WalletCoreReceiveAddressTests` — 11/11 tests passing (EVMModule, FlowModule, WalletCore suites); fixed actor isolation (`try await storeFlowAddress`), key lookup by `chain.chainId`, and 32-byte key trimming before store
- [x] `BitcoinModuleReceiveAddressTests` / `SolanaModuleReceiveAddressTests` — 8/8 passing; discovered `BitcoinModule.getReceiveAddress` uses fixed `"masterKey"` identifier (not chain-scoped like EVM), test store/delete keys adjusted accordingly; added mainnet/testnet version-byte differentiation test
- [x] AGWallet build clean under Swift 6.3 / arm64-apple-macosx26.0

## Milestone 17: Swift 6.3 / macOS 26 Toolchain Compatibility (2026-08-14)

- [x] Bumped `.macOS(.v14)` → `.macOS(.v15)` in `Package.swift` to satisfy Swift 6.3 toolchain minimum
- [x] All downstream `solana-swift-concurrency` fixes landed (P256K API, socket guards, TaskRetryingError)
- [x] `AGWallet` build clean under Swift 6.3 / arm64-apple-macosx26.0
