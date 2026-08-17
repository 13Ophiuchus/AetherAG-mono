## Milestone 20: Flow Transaction History via Events (2026-08-16)

- [x] `FlowModule.getTransactionHistory` — replaced empty-array stub with real implementation querying `FungibleToken.TokensDeposited`/`TokensWithdrawn` events over a 5000-block lookback via `FlowAccessProtocol.getEventsForHeightRange`
- [x] `FlowTokenEventType` — pure helper resolving canonical `A.<address>.FlowToken.<Event>` identifiers per mainnet/testnet chain ID
- [x] `FlowTransactionHistoryMatcher` — pure helper fixing a matching bug where `TokensWithdrawn` events (which only populate `from`, not `to`) would have been silently dropped by a naive `to`-only guard
- [x] `FlowTokenEventTypeTests` / `FlowTransactionHistoryMatcherTests` — 8/8 Swift Testing tests covering contract address resolution (mainnet/testnet) and event-matching edge cases (nil fields, mismatched address)
- [x] AGWallet build clean under Swift 6.3 / arm64-apple-macosx26.0

## Milestone 19: Flow Token Transfer Signing Bridge (2026-08-15)

- [x] `FlowModule.send` rewritten using real `CadenceTargetType` + `FlowSigner` API instead of placeholder/stub
- [x] `TransferFlowTokenTarget` — `CadenceTargetType` conformance for plain FlowToken transfers (cadenceBase64 script, ufix64/address arguments)
- [x] `KeyManagerFlowSigner` — bridges `FlowSigner` protocol to `KeyManagerActor.signFlowTransactionEnvelope`, keeping raw key material inside the actor boundary
- [x] Fixed invalid redeclaration bug — duplicate `TransferFlowTokenTarget` block (introduced by a non-idempotent append-only patch script) removed; only one definition remains
- [x] AGWallet build clean under Swift 6.3 / arm64-apple-macosx26.0 (70/70 targets, FlowModule.swift + AetherWalletKit module emission)
- [x] `TransferFlowTokenTargetTests` — 3/3 Swift Testing tests passing (cadence script content, ufix64/address argument encoding+order, CadenceTargetType metadata); fixed private->internal visibility for @testable access and ObjectIdentifier workaround for #expect metatype comparison macro bug

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
