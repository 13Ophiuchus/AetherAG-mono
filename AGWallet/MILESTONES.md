## Milestone 17: Swift 6.3 / macOS 26 Toolchain Compatibility (2026-08-14)

- [x] Bumped `.macOS(.v14)` → `.macOS(.v15)` in `Package.swift` to satisfy Swift 6.3 toolchain minimum
- [x] All downstream `solana-swift-concurrency` fixes landed (P256K API, socket guards, TaskRetryingError)
- [x] `AGWallet` build clean under Swift 6.3 / arm64-apple-macosx26.0
