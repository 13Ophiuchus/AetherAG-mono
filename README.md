# AetherAgenticGenesis-monorepo

A Swift monorepo with three sibling packages:

- `AetherAGMailShared`
- `AetherAG.mail`
- `AetherAGMailServer`

## Build and test

```bash
cd AetherAGMailShared && swift build && swift test --enable-swift-testing
cd ../AetherAG.mail && swift build && swift test --enable-swift-testing
cd ../AetherAGMailServer && swift build && swift test
```

## Open in Xcode

```bash
xed .
```
