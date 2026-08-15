## Milestone 18: getReceiveAddress across all chains (2026-08-15)

- [x] `FlowModule.getReceiveAddress` — restored guard with `try await keyManager.flowAddress()`; removed orphaned throw/return lines outside guard scope
- [x] `EVMModule.getReceiveAddress` — added using existing `getEthereumAddress` private helper; returns `EthereumAddress.address` string
- [x] `WalletCore.getReceiveAddress` — rewritten inside actor; all four chain arms wired; `ChainConfigurationService.getPredefinedChains()` called with `await`
- [x] AGWallet build clean under Swift 6.3 / arm64-apple-macosx26.0

## Milestone 17: Swift 6.3 / macOS 26 Toolchain Compatibility (2026-08-14)

- [x] Bumped `.macOS(.v14)` → `.macOS(.v15)` in `Package.swift` to satisfy Swift 6.3 toolchain minimum
- [x] All downstream `solana-swift-concurrency` fixes landed (P256K API, socket guards, TaskRetryingError)
- [x] `AGWallet` build clean under Swift 6.3 / arm64-apple-macosx26.0
