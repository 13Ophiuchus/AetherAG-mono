# AetherAG-mono — MASTER_MILESTONES.md

Consolidated from confirmed, directly-retrieved content of `AGWallet/MILESTONES.md`,
`AetherAG/MILESTONES.md`, and `git log --oneline` across both repos, supplied via terminal
output in this session on 2026-09-08. **This replaces an earlier version of this file that
relied on stale/superseded planning drafts and materially misrepresented the current state
of Flow module support and OID4VP/revocation work — see the "Corrections" section at the
bottom.**

Per project instructions, the two canonical living files remain:
- `AGWallet/MILESTONES.md` — wallet core milestones.
- `AetherAG/MILESTONES.md` — app + backend milestones.

This MASTER file is a cross-repo chronological index, not a replacement — update the
per-repo file first when a milestone completes, then reflect it here.

**Coverage note**: full milestone text is confirmed for AGWallet M17–M22 and AetherAG M65,
M67–M69. Earlier milestones (AGWallet M1–16, AetherAG M1–45) are only evidenced by commit
subjects where visible in `git log`, or not evidenced at all. Numbered gaps below are marked
`[gap]` rather than invented.

---

## Part A — AGWallet (Wallet Core SDK)

### A-gap. Milestones 1–16
Not yet retrieved in full. Known from cross-references in later milestones: domain model
(`ChainConfig`, `ChainModule`, `UnifiedTransaction`), EVM/Bitcoin/Solana module scaffolding,
Secure Enclave `KeyManagerActor`, and (per AetherAG-side commit `11c21c7`) "PBKDF2 hardening
+ Linux cross-platform fixes" attributed to a paired Milestone 16, were all established
before Milestone 17.

### Milestone 17 — Swift 6.3 / macOS 26 Toolchain Compatibility (2026-08-14)
- [x] Bumped `.macOS(.v14)` → `.macOS(.v15)` in `Package.swift` for Swift 6.3 toolchain
      minimum.
- [x] Downstream `solana-swift-concurrency` fixes landed (P256K API, socket guards,
      `TaskRetryingError`).
- [x] Build clean under Swift 6.3 / arm64-apple-macosx26.0.

### Milestone 18 — getReceiveAddress Across All Chains (2026-08-15)
- [x] `FlowModule.getReceiveAddress` — restored guard via `try await keyManager.flowAddress()`.
- [x] `EVMModule.getReceiveAddress` — added using existing `getEthereumAddress` helper.
- [x] `WalletCore.getReceiveAddress` — rewritten inside actor; all four chain arms wired;
      `ChainConfigurationService.getPredefinedChains()` called with `await`.
- [x] `WalletCoreReceiveAddressTests` — 11/11 passing (fixed actor isolation, key lookup by
      `chain.chainId`, 32-byte key trimming before store).
- [x] `BitcoinModuleReceiveAddressTests`/`SolanaModuleReceiveAddressTests` — 8/8 passing;
      discovered `BitcoinModule.getReceiveAddress` uses a fixed `"masterKey"` identifier
      (not chain-scoped like EVM) — test store/delete keys adjusted accordingly; added
      mainnet/testnet version-byte differentiation test.
- [x] Build clean.

### Milestone 19 — Flow Token Transfer Signing Bridge (2026-08-15)
- [x] `FlowModule.send` rewritten using real `CadenceTargetType` + `FlowSigner` API,
      replacing placeholder/stub.
- [x] `TransferFlowTokenTarget` — `CadenceTargetType` conformance for FlowToken transfers.
- [x] `KeyManagerFlowSigner` — bridges `FlowSigner` to
      `KeyManagerActor.signFlowTransactionEnvelope`, keeping raw key material inside the
      actor boundary.
- [x] Fixed invalid-redeclaration bug (duplicate `TransferFlowTokenTarget`, introduced by a
      non-idempotent append-only patch script).
- [x] Build clean (70/70 targets); `TransferFlowTokenTargetTests` 3/3 passing (fixed
      private→internal visibility for `@testable` access; `ObjectIdentifier` workaround for
      an `#expect` metatype-comparison macro bug).

### Milestone 20 — Flow Transaction History via Events (2026-08-16)
- [x] `FlowModule.getTransactionHistory` — replaced empty-array stub with real
      implementation querying `FungibleToken.TokensDeposited`/`TokensWithdrawn` events
      (5000-block lookback via `FlowAccessProtocol.getEventsForHeightRange`).
- [x] `FlowTokenEventType` — resolves canonical `A.<address>.FlowToken.<Event>` identifiers
      per mainnet/testnet chain ID.
- [x] `FlowTransactionHistoryMatcher` — fixes dropped-`TokensWithdrawn`-events bug (events
      only populate `from`, not `to`; naive `to`-only guard silently dropped them).
- [x] `FlowTokenEventTypeTests`/`FlowTransactionHistoryMatcherTests` — 8/8 passing.
- [x] **Self-correction recorded in-milestone**: initial commit `ed28ee1` added the helpers
      + tests, but two patch substitutions silently failed, leaving
      `getTransactionHistory` on old buggy inline logic; caught via grep, re-wired in
      follow-up commit `95cb5a5`.
- [x] Build clean.

### Milestone 21 — Flow Script Execution + ChainID Consolidation (2026-08-17)
- [x] `FlowModule.executeScript` — replaced `unsupportedOperation` stub with real Cadence
      execution via `FlowAccessProtocol.executeScriptAtLatestBlock`.
- [x] Signature widened to `executeScript(_:arguments:on:)` — `Flow().accessAPI` reads from
      the shared actor-isolated `FlowActors.access` singleton with global configuration
      state; an unconfigured client would silently execute against whichever chain was last
      configured elsewhere in the process.
- [x] `FlowChainIDResolver` — extracted duplicated `ChainConfig` → `Flow.ChainID` mapping
      (previously repeated across `getBalance`/`send`/`getTransactionHistory`/
      `executeScript`) into one pure, tested helper.
- [x] `FlowChainIDResolverTests` — 3/3 (mainnet, testnet, fallback-to-mainnet for
      signet/regtest/devnet/local).
- [x] Fixed stale `FlowModuleTests.testSendTransaction` (leftover pre-M19 assertion
      expecting `unsupportedOperation`; now expects `keychainError`).
- [x] Confirmed via grep: no pre-existing `executeScript` call sites, so signature change
      is non-breaking.
- [x] Full suite: 81/81 tests passing.

### Milestone 22 — WalletCore Flow Integration (2026-08-17)
- [x] `WalletCore.enableFlow` default flipped `false` → `true`, matching
      Bitcoin/EVM/Solana, now that `FlowModule` has no remaining stubs.
- [x] `WalletCore.executeFlowScript(_:arguments:on:)` — new facade bridging to
      `FlowModule.executeScript`.
- [x] Confirmed via grep: all existing `WalletCore(...)` call sites already pass
      `enableFlow` explicitly — default flip is non-breaking.
- [x] 3/3 new tests: non-Flow chain rejection, disabled-module rejection,
      default-initializer-enables-Flow verification.
- [x] Full suite: **84/84 tests passing** across Bitcoin/EVM/Solana/Flow/WalletCore, Swift
      6.3 / arm64-apple-macosx26.0.
- **This is the milestone at which Flow moved from "deliberately experimental, all stubs"
  to fully implemented and enabled-by-default** — supersedes all earlier characterizations
  of Flow as unsupported.

### A-gap. Milestones 23+ (AGWallet)
Not yet retrieved. Current Bitcoin/Solana completeness beyond M18's receive-address parity
(native balance, SPL tokens, chain-specific signing helpers referenced as outstanding in
older drafted material) should be reconfirmed against the live file — do not assume the
pre-M17 "TODO" language still applies given how much shipped in the M17–M22 window alone.

### A. Cross-session dependency fix (2026-09-06/07, shared with AetherAG M69)
- [x] swift-crypto range widened in `AGWallet/Package.swift` to `"4.5.1"..<"5.0.0"`,
      resolving consistently with jwt-kit 5.6.0 across AetherAG/AGWallet/flow-swift-macos.
      160/160 tests, 50 suites, release build clean. Full detail under AetherAG M69 below.

---

## Part B — AetherAG (Client App + Vapor Backend + Web)

### B-gap. Milestones 1–15
Not yet retrieved.

### Milestone 16 (AetherAG-side) — PBKDF2 Hardening + Linux Cross-Platform Fixes
Confirmed only via commit subject (`11c21c7`); full text not yet retrieved.

### Milestone 17 (AetherAG-side) — Swift 6.3 Toolchain Compat
Confirmed only via commit subject (`7e1eb04`, "build clean"); paired with AGWallet M17.

### Milestone 18 (AetherAG-side) — Wallet UI + getReceiveAddress Complete
Confirmed only via commit subject (`c1830da`); paired with AGWallet M18.

### Milestone 19+21 (AetherAG-side) — Swift 6 Actor Isolation Fixes, macOS Compat
Confirmed via commit `4b1d6c9` ("Swift 6 actor isolation fixes, macOS compat, Milestone
19+21 complete") — tracked jointly with AGWallet's M19/M21 at this point in history.
Also this commit: `0e98f75` "add onboarding and wallet scaffolding" (client app work,
adjacent in the log).

### Milestone 20 (AetherAG-side) — Full Test Suite Green
Confirmed via commit `270e228` ("close out Milestone 20 - full test suite green, 0 known
failures"); distinct from AGWallet's own M20 (Flow transaction history).
Adjacent fix commits in the log: `14b2def` (wire-format/fixture mismatches),
`751c7fe` (sign request-object JWTs via `app.jwtSigningService`), `ac0e17e` (SQL syntax fix
in `VerificationRepository`).

### B-gap. Milestones 23–45
Not yet retrieved.

### Milestones 46–49 (commit `1af820b`)
- [x] `ActivityViewModel` tests.
- [x] `WalletCreationViewModel`.
- [x] `CredentialOfferViewModel` persistence.
- [x] OID4VCI smoke tests.
- [x] 145 tests passing.

### B-gap. Milestones 50–54
Not yet retrieved.

### Milestones 55–59 (commit `f9e36b0`)
- [x] `IssueCredentialJob` sign+persist.
- [x] `ExpireIssuanceSessionsJob` SQL.
- [x] **`VPSubmissionController` — OID4VP submissions implemented.**
- [x] **`CredentialStatusController` — DB-backed credential status/revocation implemented.**
- [x] `IdentityTabViewModel`.
- [x] `WalletOnboardingViewModel`.
- [x] 160 tests passing.
- **Correction**: this directly contradicts an earlier superseded planning draft that
  characterized OID4VP and revocation as "not started." Both were implemented by this
  point. Full phase-by-phase detail (exact request/response shapes, presentation_definition
  handling, status-list bit-array format) was not retrieved — confirm current
  implementation detail against source directly if you need spec-level accuracy.

### B-gap. Milestones 60–64, and Milestone 66
Not yet retrieved. (M65, M67, M68, M69 are covered below.)

### Milestone 65 (commit `fe213db`) — Apple Container Integration
- [x] OCI `Containerfile`, `container-dev.sh`, `ci-container.sh`, GitHub Actions workflow.
- [x] Docker path preserved alongside the new native-container path.
- [x] 160 tests passing.

### Milestone 67 — Full Mono Docker Build Green (2026-09-02)
**flow-swift-macos fixes:**
- [x] Fixed corrupted nested `#if canImport(CryptoKit)` blocks in `P256Signer.swift` /
      `P256FlowSigner.swift`.
- [x] Added `@unchecked Sendable` to `ECDSA_P256_Signer` (non-Sendable
      `P256.Signing.PrivateKey` on Linux swift-crypto) — later removed again in M69 once no
      longer needed.
- [x] Fixed `currentClient()` call-site typo in `Cadence+Token.swift` (computed property,
      not a function).
- [x] Added swift-crypto as an explicit `Package.swift` dependency.

**AGWallet fixes:**
- [x] Resolved package-identity conflict: `flow-swift-macos` switched from pinned GitHub
      revision to local path dependency, matching AetherAG's own reference.
- [x] Platform-gated `Security`/`LocalAuthentication`/`CryptoKit`/`os.log`/
      `FoundationNetworking` across `ChainConfigurationService`, `KeyManager`,
      `KeyStorageProviding`, `Mnemonic`, `Logger`, `BitcoinModule`, `BitcoinEsploraClient` —
      Secure Enclave/Keychain behavior preserved on Apple platforms;
      `SystemRandomNumberGenerator`/in-memory fallbacks on Linux.

**AetherAGMailServer fixes:**
- [x] Fixed `DIDResolver`'s `URLSession` platform availability and `Sendable` conformance.
- [x] Gated `CryptoKit` in `configureSecurity.swift`, `P256ECDSASignatureDER.swift`,
      `Ed25519JWSVerifier.swift`, `ES256JWSVerifier.swift`, `JWKThumbprint.swift`,
      `CredentialIssuanceService.swift`, `IssuerKeyProvider.swift`.
- [x] Fixed `VerificationRequestService.generateNonce()` CSPRNG fallback.

**Containerfile fixes:**
- [x] Added missing `COPY AetherAG/Public ./Public` in builder stage.
- [x] Added `COPY --from=builder /usr/lib/swift/linux /usr/lib/swift/linux` (Swift runtime
      shared libraries absent from bare `ubuntu:24.04`).
- [x] `swift build -c release --product AetherAGMailServerRun` completes ~150s; image
      builds/exports as `aetherag-mono:dev`.
- [x] Verified via `docker run`: Flow runtime (testnet) configured, in-memory DB mode,
      serves on `0.0.0.0:8080`, `200` on `GET /`.

### Milestone 68 — Native Container Build Path Fixed + Verified (2026-09-02)
- [x] Removed redundant native `swift build` step from `scripts/ci-container.sh` and
      `scripts/container-dev.sh` (multi-stage `Containerfile` already builds via its own
      `swift:6.2-noble` builder stage).
- [x] Repointed both scripts from `Containerfile.prebuilt` to canonical `Containerfile`.
- [x] `container build -f Containerfile -t aether-server:ci-local .` succeeds under Apple's
      `container` CLI 1.2.2 (29/29 stages; full cache hit 43.6s after 1057.7s cold build).
      Previously-documented "buildkit /tmp SIP bug" did not reproduce.
- [x] Fixed `PG_IP` extraction in `container-dev.sh`: corrected JSON path to
      `status.networks[0].ipv4Address` (stripping `/24`) — prior path silently used the
      wrong container's IP.
- [x] `scripts/container-dev.sh rebuild` verified end-to-end: image build, `aether-dev`
      against `pg-test` (192.168.64.5), all 5 SQL migrations applied, Redis connected,
      `GET /` → 200.
- [x] Reclaimed ~35GB Apple container disk usage (stale containers + superseded Swift
      toolchain images), unblocking `ENOSPC` failures.
- [ ] `Containerfile.prebuilt` retained for reference, unreferenced by any script —
      candidate for removal once confirmed unused elsewhere.
- [ ] `aether-server:demo` tag resists `container image rm` (shares digest with `dev`,
      zero disk cost) — cosmetic, not blocking.

### Milestone 69 — swift-crypto Cross-Package Conflict Resolved + flow-swift-macos Submodule Registration Fixed (2026-09-06, corrected 2026-09-08)
- [x] Root cause: `flow-swift-macos` capped swift-crypto at `from: "3.0.0"`
      (implicit `3.0.0..<4.0.0`), conflicting with jwt-kit 5.6.0's requirement for
      swift-crypto >= 4.5.1 — silently forced the whole graph to swift-crypto 3.15.1 /
      jwt-kit 5.2.0 on every `swift package resolve`, despite `Package.resolved` on
      `origin/main` pinning 4.5.1/5.6.0.
- [x] Widened `flow-swift-macos/Package.swift` swift-crypto range to `"3.0.0"..<"5.0.0"`;
      confirmed no 3.x-specific Crypto API usage broke.
- [x] Raised `AGWallet/Package.swift` swift-crypto floor to `"4.5.1"..<"5.0.0"`; switched
      `flow-swift-macos` to a local path dependency (`../flow-swift-macos`).
- [x] `ECDSA_P256_Signer`: `var privateKey` → `let privateKey`; removed
      `@unchecked Sendable` in favor of plain compiler-verified `Sendable` conformance.
- [x] Discovered `flow-swift-macos` was never registered in `.gitmodules`/`.git/config`
      despite independent remote history — silently broke the mono-repo's `pre-push`
      submodule-sync hook. Registered alongside `AetherAG`, `solana-swift-concurrency`,
      `web3swift-concurrency`; removed stale `flow-swift-macos/` line from `.gitignore`.
- [x] Verified: `swift package show-dependencies` confirms swift-crypto 4.5.2 / jwt-kit
      5.6.0 resolve consistently, no downgrades. Full release build clean; 160/160 tests,
      50 suites.
- [x] **Test-isolation fix, corrected note**: `FlowActors.access` (`FlowAccessActor.shared`)
      package-wide singleton caused cross-suite races
      (`ArgumentDecodeTests`, `ArgumentEncodeTests`, `FlowActorIntegrationTests`,
      `FlowActorUnitTests`, `CadenceTarget*Tests`, `NFTCatalogTests`). Per-suite
      `.serialized` alone confirmed insufficient (3–24 failing issues under parallel
      `swift test`). Confirmed fix: `swift test --no-parallel` (217/217, 3/3 consecutive
      clean runs). Applied to `.github/workflows/build.yml`
      (`swift test -v --no-parallel`). Commits: `c09a2cb` (flow-swift-macos — push
      initially blocked by a GitHub account email-verification 403, resolved and
      succeeded), `3a3634c` + `77dc7ad` (AetherAG-mono submodule bumps + corrected
      milestone note), `fa28928` (AetherAG milestone-note correction itself).

---

## Part C — Cross-Repo / Housekeeping Backlog

- [ ] **Containerfile consolidation** — `.bak`/`.demo`/canonical `Containerfile` variants
      coexist (see M68 open items).
- [ ] **Branch-naming standardization** — `main` (AetherAG-mono, flow-swift-macos) vs.
      `master` (inner AetherAG). Document explicitly or unify.
- [ ] **`AetherAGMailServer` CI parallel-test audit** — check for shared-singleton/
      shared-mock state analogous to `FlowActors.access` (precedent: M69's flow-swift-macos
      fix).
- [ ] **Retrieve missing milestone ranges** listed under each `[gap]` marker above, ideally
      directly from `cat`/`sed` output of the live files, before relying on this document
      for anything earlier than the confirmed windows.
- [ ] **`solana-swift-concurrency/MILESTONES.md`** — exists, not yet read into this
      consolidation.

---

## Corrections From Prior Version of This Document

The version of `MASTER_MILESTONES.md` produced earlier in this session (before live
terminal output was available) contained two significant errors, now corrected above:

1. **Flow module status** — was described as "deliberately experimental," all
   `unsupportedOperation` stubs. In reality, Flow was fully implemented (balance, send,
   history, script execution, signing) and enabled by default as of AGWallet Milestone 22
   (2026-08-17).
2. **OID4VP / revocation status** — was described as "not started" per an old planning
   draft (`MILESTONES-1.md`). In reality, both `VPSubmissionController` (OID4VP) and
   `CredentialStatusController` (DB-backed revocation/status) were implemented by AetherAG
   Milestones 55–59.

Additionally, the dependency repo previously called `solana-swift-patched` is actually
named `solana-swift-concurrency` — corrected throughout.

## Change Log

- 2026-09-08 (16:41 EDT): Rebuilt from live `git log`/`cat` terminal output; superseded the
  earlier cached-draft-based version; explicit gap-marking introduced for unretrieved
  milestone ranges.
