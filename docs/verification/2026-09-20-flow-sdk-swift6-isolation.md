# Flow SDK Swift 6 Isolation Verification

Date: 2026-09-20

## Published revisions

- Flow SDK: `f6ebc4313f2e93d84e53dbd478088761b3b6e1bb`
  (`Fix Flow actor sendability and decode isolation`)
- AetherAG monorepo gitlink update: `28dc5c8`

## Validation performed

- `flow-swift-macos`: `swift build -Xswiftc -strict-concurrency=complete` passed.
- `flow-swift-macos`: `swift test -Xswiftc -strict-concurrency=complete` passed:
  218 tests across 30 suites.
- `AGWallet`: strict-concurrency build and test validation passed.
- A clean recursive clone checked out Flow submodule revision `f6ebc43`.
