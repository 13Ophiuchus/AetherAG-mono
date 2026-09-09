# AetherAG-mono — Project State

_Compiled 2026-09-08 16:41 EDT, from direct terminal output (git log + cat/sed of live
MILESTONES.md files) supplied in-session, superseding an earlier draft of this document that
relied on stale cached historical files and materially misstated AGWallet's Flow module
status. Where the underlying milestone history has gaps not yet supplied (see "Coverage
Gaps" in each section), those gaps are stated explicitly rather than filled with guesses._

---

## 1. Repository Map

| Repo / path | Role | Notes |
|---|---|---|
| `AGWallet/` | Multi-chain wallet SDK (Bitcoin, EVM, Solana, Flow) | Confirmed history through **Milestone 22** (2026-08-17); default branch `main` |
| `AetherAG/` | Mail/identity client + Vapor backend (`AetherAGMailServer`) + Leaf web | Confirmed history through **Milestone 69** (2026-09-06, corrected 2026-09-08); default branch **`master`** |
| `flow-swift-macos/` | Patched Flow Swift SDK, now a properly registered git submodule | Fixed test-isolation race this session; branch `main` |
| `solana-swift-concurrency/` | Patched Solana Swift dependency (concurrency-focused fork) | Has its own `MILESTONES.md`; referenced directly in AetherAG commits `6a51647`, `4b1d6c9`. **Correction**: earlier drafts of this document called this `solana-swift-patched` — the actual directory/repo name is `solana-swift-concurrency`. Content of its `MILESTONES.md` not yet retrieved. |
| `web3swift-concurrency/` | web3swift fork for EVM module | Appears as modified submodule pointer in working tree; no milestone content retrieved yet |
| `Aether.xcworkspace` | Xcode workspace tying app + wallet together | — |
| Container tooling | `Containerfile`, `scripts/ci-container.sh`, `scripts/container-dev.sh` | Covered under AetherAG Milestones 65–68 |

**Branch-naming note (confirmed)**: `AetherAG-mono` and `flow-swift-macos` use `main`;
the inner `AetherAG` repo uses `master`. This has already caused at least one failed push
attempt this session and should be documented or standardized.

---

## 2. AGWallet — Wallet Core SDK

### Confirmed milestone history (M17 → M22, most recent first)

**Milestone 22 — WalletCore Flow Integration (2026-08-17)**
- `WalletCore.enableFlow` default flipped `false` → `true`, matching Bitcoin/EVM/Solana,
  since `FlowModule` had no remaining stubs at this point.
- `WalletCore.executeFlowScript(_:arguments:on:)` — new facade bridging to
  `FlowModule.executeScript`, exposed outside the shared `ChainModule` switch pattern.
- Confirmed via grep that all existing `WalletCore(...)` call sites already pass
  `enableFlow` explicitly, making the default flip non-breaking.
- 3/3 new tests: non-Flow chain rejection, disabled-module rejection,
  default-initializer-enables-Flow verification.
- **Full suite: 84/84 tests passing** across Bitcoin/EVM/Solana/Flow/WalletCore, Swift 6.3 /
  arm64-apple-macosx26.0.

**Milestone 21 — Flow Script Execution + ChainID Consolidation (2026-08-17)**
- `FlowModule.executeScript` — replaced `unsupportedOperation` stub with real Cadence
  script execution via `FlowAccessProtocol.executeScriptAtLatestBlock`.
- Signature widened to `executeScript(_:arguments:on:)` — required because
  `Flow().accessAPI` reads from **`FlowActors.access`**, a shared actor-isolated singleton
  with global configuration state; an unconfigured client would otherwise silently execute
  against whichever chain was last configured elsewhere in the process. (This is the same
  singleton whose test-isolation implications were fully root-caused and fixed later, in
  flow-swift-macos, during this session — see Section 4.)
- `FlowChainIDResolver` — extracted the `ChainConfig` → `Flow.ChainID` mapping duplicated
  across `getBalance`/`send`/`getTransactionHistory`/`executeScript` into one pure, tested
  helper.
- `FlowChainIDResolverTests` — 3/3 tests (mainnet, testnet, fallback-to-mainnet for
  signet/regtest/devnet/local).
- Fixed a stale `FlowModuleTests.testSendTransaction` assertion left over from
  pre-Milestone-19 expecting `unsupportedOperation`; corrected to expect `keychainError`.
- **Full suite: 81/81 tests passing.**

**Milestone 20 — Flow Transaction History via Events (2026-08-16)**
- `FlowModule.getTransactionHistory` — replaced empty-array stub with a real
  implementation querying `FungibleToken.TokensDeposited`/`TokensWithdrawn` events over a
  5000-block lookback via `FlowAccessProtocol.getEventsForHeightRange`.
- `FlowTokenEventType` — pure helper resolving canonical `A.<address>.FlowToken.<Event>`
  identifiers per mainnet/testnet chain ID.
- `FlowTransactionHistoryMatcher` — fixes a matching bug where `TokensWithdrawn` events
  (which only populate `from`, not `to`) would have been silently dropped by a naive
  `to`-only guard.
- 8/8 tests covering contract address resolution and event-matching edge cases.
- **Notable self-correction recorded in the milestone itself**: the initial commit
  (`ed28ee1`) added the helpers + tests but two patch substitutions silently failed,
  leaving `getTransactionHistory` on the old buggy inline logic; this was caught via grep
  and re-wired in a follow-up commit. Worth remembering as a recurring failure mode —
  patch/substitution steps silently not applying — when doing future automated edits.

**Milestone 19 — Flow Token Transfer Signing Bridge (2026-08-15)**
- `FlowModule.send` rewritten using real `CadenceTargetType` + `FlowSigner` API instead of
  a placeholder/stub.
- `TransferFlowTokenTarget` — `CadenceTargetType` conformance for plain FlowToken transfers.
- `KeyManagerFlowSigner` — bridges `FlowSigner` protocol to
  `KeyManagerActor.signFlowTransactionEnvelope`, keeping raw key material inside the actor
  boundary.
- Fixed an invalid-redeclaration bug (duplicate `TransferFlowTokenTarget` block introduced
  by a non-idempotent append-only patch script).
- Build clean (70/70 targets); `TransferFlowTokenTargetTests` 3/3 passing.

**Milestone 18 — getReceiveAddress across all chains (2026-08-15)**
- `FlowModule.getReceiveAddress`, `EVMModule.getReceiveAddress` (new, via
  `getEthereumAddress` helper), `WalletCore.getReceiveAddress` (rewritten inside actor; all
  four chain arms wired).
- `WalletCoreReceiveAddressTests` 11/11; `BitcoinModuleReceiveAddressTests`/
  `SolanaModuleReceiveAddressTests` 8/8 — discovered `BitcoinModule.getReceiveAddress` uses
  a fixed `"masterKey"` identifier (not chain-scoped like EVM).

**Milestone 17 — Swift 6.3 / macOS 26 Toolchain Compatibility (2026-08-14)**
- Bumped `.macOS(.v14)` → `.macOS(.v15)` in `Package.swift` for the Swift 6.3 toolchain
  minimum; downstream `solana-swift-concurrency` fixes landed (P256K API, socket guards,
  `TaskRetryingError`); build clean.

### Corrected module status (supersedes earlier drafted-baseline description)

| Module | Balance | Send | History | Signing | Status as of M22 |
|---|---|---|---|---|---|
| Bitcoin | ✅ (Esplora UTXO sum) | ⚠️ historically partial — confirm current state | ✅ Esplora | ✅ receive address (M18); other signing status unconfirmed post-M18 | Was mid-implementation as of older drafts; M18 shows receive-address parity achieved |
| EVM | ✅ native + ERC-20 | ✅ | ⚠️ historically partial (no indexer) | ✅ `signMessage` + receive address (M18) | Most mature module in earlier drafts |
| Solana | Unconfirmed post-M18 | Unconfirmed | Unconfirmed | Receive address done (M18); message signing was stubbed in older drafts | Needs current-state confirmation |
| **Flow** | ✅ real (M20, event-based) | ✅ real (M19, real Cadence signing) | ✅ real (M20) | ✅ real (M19, `KeyManagerFlowSigner`) | **Fully implemented and enabled by default as of M22** — this reverses the "deliberately experimental, all-stubs" characterization used in the previous version of this document |

**Coverage gap**: Milestones 1–16 and 23+ (if they exist) have not been retrieved. The
table above should be treated as accurate for the M17–M22 window specifically, not
necessarily AGWallet's current `HEAD`.

### This session's confirmed AGWallet-adjacent work
- swift-crypto/jwt-kit cross-package dependency conflict resolved (see AetherAG M69 below —
  same fix, touches `AGWallet/Package.swift`).
- flow-swift-macos test-isolation root-caused and fixed (see Section 4).

---

## 3. AetherAG — Mail/Identity Client + Vapor Backend + Web

### Important correction
An earlier version of this document described AetherAG's backend roadmap using
Phase-1-through-7 OID4VCI language (holder proof validation pending, OID4VP not started,
revocation not started, etc.) sourced from a document called `MILESTONES-1.md`. Given the
real `AetherAG/MILESTONES.md` now confirmed to run through **Milestone 69** and to already
reference "VPSubmissionController OID4VP" and "CredentialStatusController DB" as **shipped**
(in the M55–M59 commit `f9e36b0`), that Phase-1–7 document was an **early planning draft
that was superseded by actual implementation**, not a live description of current gaps. Do
not treat the OID4VP/revocation "not started" claims as current.

### Confirmed milestone history (partial — M65 through M69, plus commit-log fragments back to M16)

**Milestone 69 — swift-crypto Cross-Package Conflict Resolved + flow-swift-macos Submodule Registration Fixed (2026-09-06, note corrected 2026-09-08)**
- Root cause: `flow-swift-macos` capped swift-crypto at `from: "3.0.0"` (implicit
  `3.0.0..<4.0.0`), conflicting with jwt-kit 5.6.0's swift-crypto >= 4.5.1 requirement in
  AetherAGMailServer — silently forcing the whole graph down to swift-crypto 3.15.1 /
  jwt-kit 5.2.0 on every `swift package resolve`, despite `Package.resolved` on
  `origin/main` pinning 4.5.1/5.6.0.
- Widened `flow-swift-macos/Package.swift` swift-crypto range to `"3.0.0"..<"5.0.0"`;
  confirmed no 3.x-specific Crypto API usage broke.
- Raised `AGWallet/Package.swift` swift-crypto floor to `"4.5.1"..<"5.0.0"`; switched
  `flow-swift-macos` from a pinned GitHub revision to a local path dependency
  (`../flow-swift-macos`).
- `ECDSA_P256_Signer`: `var privateKey` → `let privateKey`; removed `@unchecked Sendable`
  in favor of compiler-verified `Sendable`.
- Discovered `flow-swift-macos` was never registered in `.gitmodules`/`.git/config` despite
  independent remote history — silently broke the mono-repo's `pre-push` submodule-sync
  hook. Registered alongside `AetherAG`, `solana-swift-concurrency`, `web3swift-concurrency`;
  removed a stale `flow-swift-macos/` line from `.gitignore` that suppressed its gitlink.
  swift-crypto 4.5.2 / jwt-kit 5.6.0 confirmed resolving consistently; 160/160 tests, 50
  suites, release build clean.
- **Test-isolation fix (this session, corrected version of the note)**: root-caused
  `FlowActors.access` (`FlowAccessActor.shared`) as a package-wide singleton shared across
  `ArgumentDecodeTests`, `ArgumentEncodeTests`, `FlowActorIntegrationTests`,
  `FlowActorUnitTests`, `CadenceTarget*Tests`, `NFTCatalogTests`. Per-suite `.serialized`
  alone was confirmed insufficient (still 3–24 failing issues under parallel `swift test`).
  Confirmed fix: `swift test --no-parallel` (217/217, 3/3 consecutive clean runs). Applied
  to `.github/workflows/build.yml`. Commits: `c09a2cb` (flow-swift-macos, successfully
  pushed after a GitHub email-verification block was resolved), `3a3634c`/`77dc7ad`
  (AetherAG-mono submodule bumps), `fa28928` (AetherAG milestone note correction).

**Milestone 68 — Native Container Build Path Fixed + Verified (2026-09-02)**
- Resolved the gap left by Milestone 66's `Containerfile.prebuilt` workaround: the
  canonical multi-stage `Containerfile` now builds and runs under both Docker and Apple's
  native `container` CLI (v1.2.2), no native macOS `swift build` step required.
- Removed redundant native `swift build` step from `ci-container.sh`/`container-dev.sh`;
  repointed both scripts from `Containerfile.prebuilt` to the canonical `Containerfile`.
- `container build` succeeds end-to-end under Apple's `container` CLI (29/29 stages, cache
  hit in 43.6s after a 1057.7s cold build); the previously-documented "buildkit /tmp SIP
  bug" did not reproduce — root cause of prior failures was unrelated.
- Fixed `PG_IP` extraction in `container-dev.sh`: wrong JSON path
  (`network.interfaces.eth0.ipv4.address`) silently fell back to a hardcoded IP belonging
  to the wrong container; corrected to `status.networks[0].ipv4Address`.
- `container-dev.sh rebuild` verified end-to-end (migrations, Redis, HTTP 200 on `GET /`).
- Reclaimed ~35GB of Apple container disk usage, unblocking `ENOSPC` build failures.
- Open items: `Containerfile.prebuilt` retained but unreferenced (candidate for removal);
  `aether-server:demo` tag resists removal (cosmetic, shares digest with `dev`).

**Milestone 67 — Full Mono Docker Build Green (2026-09-02)**
- Resolved the full chain of Linux cross-platform build failures blocking
  `docker build -f Containerfile -t aetherag-mono:dev .`:
  - **flow-swift-macos**: fixed corrupted nested `#if canImport(CryptoKit)` blocks in
    `P256Signer.swift`/`P256FlowSigner.swift`; added `@unchecked Sendable` to
    `ECDSA_P256_Signer` (later removed again in M69 once no longer needed); fixed
    `currentClient()` call-site typo in `Cadence+Token.swift`; added swift-crypto as an
    explicit `Package.swift` dependency.
  - **AGWallet**: resolved package-identity conflict by switching `flow-swift-macos` to a
    local path dependency; platform-gated `Security`/`LocalAuthentication`/`CryptoKit`/
    `os.log`/`FoundationNetworking` across `ChainConfigurationService`, `KeyManager`,
    `KeyStorageProviding`, `Mnemonic`, `Logger`, `BitcoinModule`, `BitcoinEsploraClient` —
    preserving Secure Enclave/Keychain behavior on Apple platforms with
    `SystemRandomNumberGenerator`/in-memory fallbacks on Linux.
  - **AetherAGMailServer**: fixed `DIDResolver`'s `URLSession` platform availability/
    `Sendable` conformance; gated `CryptoKit` across `configureSecurity.swift`,
    `P256ECDSASignatureDER.swift`, `Ed25519JWSVerifier.swift`, `ES256JWSVerifier.swift`,
    `JWKThumbprint.swift`, `CredentialIssuanceService.swift`, `IssuerKeyProvider.swift`;
    fixed `VerificationRequestService.generateNonce()` CSPRNG fallback.
  - **Containerfile**: added missing `COPY AetherAG/Public ./Public` and
    `COPY --from=builder /usr/lib/swift/linux /usr/lib/swift/linux` (Swift runtime shared
    libraries absent from bare `ubuntu:24.04`).
- `swift build -c release --product AetherAGMailServerRun` completes in ~150s; image
  builds/exports as `aetherag-mono:dev`; verified via `docker run` — server configures Flow
  runtime (testnet), enables in-memory DB, starts on `0.0.0.0:8080`, `200` on `GET /`.

**Milestone 65 (commit `fe213db`) — Apple Container Integration**
- OCI `Containerfile`, `container-dev.sh`, `ci-container.sh`, GHA workflow; Docker path
  preserved; 160 tests passing.

### Commit-log fragments confirming intermediate work (M46–M64 window, not full milestone text)
From `git log --oneline`, several substantive commits are visible even without their full
milestone write-ups:
- `f9e36b0` — **M55–M59**: `IssueCredentialJob` sign+persist, `ExpireIssuanceSessionsJob`
  SQL, **`VPSubmissionController` (OID4VP)**, **`CredentialStatusController` (DB-backed
  revocation)**, `IdentityTabViewModel`, `WalletOnboardingViewModel` — 160 tests passing.
  This confirms OID4VP and revocation/status-list work were **implemented**, contradicting
  the "not started" status in the superseded Phase-based draft.
- `1af820b` — **M46–M49**: `ActivityViewModel` tests, `WalletCreationViewModel`,
  `CredentialOfferViewModel` persistence, OID4VCI smoke tests — 145 tests passing.
- `4b1d6c9` — Swift 6 actor isolation fixes, macOS compat, "Milestone 19+21 complete"
  (cross-reference to AGWallet's own M19/M21 — these were tracked jointly at this point).
- `270e228` — "close out Milestone 20 - full test suite green, 0 known failures"
  (AetherAG-side M20, distinct from AGWallet's M20).
- `14b2def`, `751c7fe`, `ac0e17e` — AetherAGMailServer test/wire-format fixes, JWT signing
  via `app.jwtSigningService`, SQL syntax fix in `VerificationRepository`.
- `0e98f75` — "add onboarding and wallet scaffolding" (client app work).
- `c1830da` — "Milestone 18 — wallet UI + getReceiveAddress complete" (AetherAG-side M18,
  paired with AGWallet's M18 receive-address work).
- `7e1eb04` — "Milestone 17 — Swift 6.3 toolchain compat" (AetherAG-side, paired with
  AGWallet M17).
- `11c21c7` — "Milestone 16 — PBKDF2 hardening + Linux cross-platform fixes".

**Coverage gap**: Milestones 1–15, and the detailed text of M16, M20 (AetherAG-side),
M23–45, M50–54, M60–64, and M66 have not been retrieved in full. The commit subjects above
are the only evidence available for the M46–M64 span; treat the OID4VP/revocation
"implemented" conclusion as well-evidenced but not exhaustively detailed.

### Shared module architecture (AetherShared split) — from `AetherShared-DEPENDENCY-RULES.md`
- **`AetherSharedCore`** (no internal deps) → **`AetherSharedIdentity`** (deps: Core) →
  **`AetherSharedProtocols`** (deps: Core + Identity). Hard rule: `AetherShared*` never
  depends on AGWallet/AetherAG/Vapor/Flow/BigInt; AGWallet/AetherAG may depend on
  `AetherShared*`, never the reverse.
- `DynamicCodingKeys`/`DynamicKeyedArray<Element>`/`KeyedArrayGroup<Element>` live in
  `AetherSharedCore` (Foundation-only).
- Per `migration_inventory.csv`: most Credential/DID/Issuance/Presentation/Verification DTOs
  moved to `AetherSharedIdentity` (plain move if pure-Codable, `move-now-split` if also
  Vapor `Content`-conformant); orchestration logic (`DIDResolver`, `DIDDocumentService`,
  `VCJSONCanonicalizer`, `VerificationAPI`) intentionally kept in `AetherAG`.
- `HTTPMethod.swift` → renamed `APIClient.swift`, moved to `AetherSharedCore`
  (AetherAG@e0b08c3 / AetherAG-mono@6631280).
- Remaining `move-later` items: `DIDDocumentServiceProtocol.swift`,
  `BBSPlusSigningServiceProtocol.swift` → `AetherSharedProtocols`.

**Coverage gap**: no confirmation of exactly which AetherAG milestone number(s) this
migration corresponds to, or whether it is fully complete as of `HEAD`.

---

## 4. flow-swift-macos

217 tests across 29 suites. This session's fully-verified work (see AetherAG M69 above for
full detail): root-caused and fixed a package-wide test-isolation race on the
`FlowActors.access` singleton — the same singleton whose actor-isolated global-state design
was originally noted as a deliberate constraint back in AGWallet's own Milestone 21
(`executeScript`'s widened signature exists specifically because of this singleton's
behavior). CI now runs `swift test -v --no-parallel` in `.github/workflows/build.yml`,
confirmed via 3 consecutive clean 217/217 runs before commit/push (`c09a2cb`).

---

## 5. solana-swift-concurrency & web3swift-concurrency

- **`solana-swift-concurrency`**: has its own `MILESTONES.md` (confirmed to exist via
  `find`), referenced in AGWallet M17 ("downstream `solana-swift-concurrency` fixes
  landed — P256K API, socket guards, `TaskRetryingError`") and in AetherAG commit `4b1d6c9`.
  Content not yet retrieved — **do not rely on the previous version of this document's
  "solana-swift-patched" name or description; that was incorrect.**
- **`web3swift-concurrency`**: consumed by AGWallet's EVM module; appears as a modified
  submodule pointer in the working tree as of the last `git status --short` seen this
  session. No milestone content retrieved.

---

## 6. Cross-Cutting: Build & CI Surface

- Root workflows: `.github/workflows/codeql.yml`, `docs.yml`, `presubmit.yml`,
  `generate-doc.yml`, `build.yml` (flow-swift-macos's own workflow, updated this session to
  `swift test -v --no-parallel`).
- Container build path: fixed/verified as of M67–M68; `Containerfile.bak`/`.demo` variants
  and a deleted `.prebuilt` currently coexist in the working tree unconsolidated (open
  housekeeping item, not yet resolved).
- **Open question, not yet checked**: whether `AetherAGMailServerTests`' own "parallel
  tests" CI step has any shared-singleton/shared-mock state comparable to
  `FlowActors.access` that could cause the same class of intermittent failures. Worth an
  explicit audit given the precedent.

---

## 7. Known Open Threads / Housekeeping

1. **Containerfile consolidation** — `.bak`/`.demo`/canonical `Containerfile` coexist.
2. **Branch-naming inconsistency** — `main` (mono, flow-swift-macos) vs. `master` (AetherAG).
3. **GitHub account email verification** — resolved this session after blocking a push to
   `flow-swift-macos`; worth confirming no other push paths are affected.
4. **AGWallet working-tree changes reported earlier in session** (modified but
   uncommitted): `BitcoinEsploraClient.swift`, `BitcoinModule.swift`,
   `ChainConfigurationService.swift`, `KeyManager.swift`, `KeyStorageProviding.swift`,
   `Mnemonic.swift`, `Logger.swift`, `Package.resolved` — status as of latest `git log`
   shows these areas have received substantial commits since (M17–M22), so this may be
   stale; re-run `git status --short` in `AGWallet/` to confirm current state.
5. **Xcode workspace/scheme changes** — previously reported modified/new files
   (`contents.xcworkspacedata`, `Package.resolved`, `AetherAGMailClientApp.xcscheme`,
   `xcschememanagement.plist`) — re-verify current status.

---

## Sourcing & Confidence Notes

- **High confidence** (direct terminal output this session): AGWallet M17–M22 full text;
  AetherAG M65, M67, M68, M69 (corrected) full text; AetherAG commit log M46–M69 subjects;
  flow-swift-macos test-isolation fix end-to-end.
  - **This directly reverses two claims in the prior version of this document**: Flow
    module is *not* "deliberately experimental / all-stubs" (it's fully implemented as of
    M22), and OID4VP/revocation are *not* "not started" (implemented per M55–M59).
- **Unconfirmed / gap**: AGWallet M1–16, M23+; AetherAG M1–45 full text (only commit
  subjects for M46–64), M50–54, M60–64, M66 full text; `solana-swift-concurrency` and
  `web3swift-concurrency` milestone content; current Bitcoin/Solana module completeness
  post-M18.

Before treating any "outstanding work" claim as current, confirm directly:

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet && git log --oneline -60 | tail -40
cd /Users/nicreich/AetherAG-mono/AetherAG && git log --oneline -80 | tail -40
cd /Users/nicreich/AetherAG-mono/solana-swift-concurrency && cat MILESTONES.md
```
