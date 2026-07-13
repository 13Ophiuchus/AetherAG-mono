# AetherShared Dependency Rules

- AetherSharedCore: no internal dependencies.
- AetherSharedIdentity: depends only on AetherSharedCore.
- AetherSharedProtocols: depends on AetherSharedCore + AetherSharedIdentity.
- AetherShared must NEVER depend on AGWallet, AetherAG, Vapor, Flow, or BigInt.
- AGWallet and AetherAG may depend on AetherShared targets, never the reverse.
