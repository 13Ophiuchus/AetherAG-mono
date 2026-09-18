# AetherAG-mono — Remaining Path to Production

Status as of 2026-09-14, post-Milestone 70 (EVM transaction history via indexer, commit
`730fdf8`). This supersedes item 2 of the prior gap list — EVM history via indexer is now
**done**. Everything below is still open, ordered by the same phase structure already
established in `AetherAG-mono_Architecture_and_Production_Plan.md`.

---

## Phase A — Close Known Functional Gaps (highest priority)

### A1. SolanaModule — SPL token balance + send (currently `unsupportedOperation`)

This is the single largest functional gap in AGWallet. Needs a new `KeyManagerActor`
signing helper plus associated-token-account derivation.

**Step 1 — Confirm current stub locations (read-only):**

```bash
cd ~/AetherAG-mono/AGWallet
grep -n "unsupportedOperation" Sources/AetherWalletKit/Data/SolanaModule/SolanaModule.swift
grep -n "func signSolanaTransferPayload\|func solanaAddress\|func signSolanaMessage" \
  Sources/AetherWalletKit/Data/KeyManagementModule/*.swift
```

**Step 2 — Preview the new KeyManagerActor helper (Python, idempotent, no repo writes yet):**

```python
#!/usr/bin/env python3
# preview_spl_signing_helper.py
# READ-ONLY. Writes preview to ./fix_preview/. Run: python3 preview_spl_signing_helper.py ~/AetherAG-mono
import sys, os

def main():
    repo = sys.argv[1]
    rel = "AGWallet/Sources/AetherWalletKit/Data/KeyManagementModule/KeyManager.swift"
    full = os.path.join(repo, rel)
    with open(full) as f:
        content = f.read()

    anchor = "func signSolanaTransferPayload"
    if anchor not in content:
        print(f"!! anchor '{anchor}' not found -- inspect file structure manually first.")
        sys.exit(1)

    print("Anchor found. Next: add a sibling method")
    print("  func signSPLTransferPayload(_ payload: Data, chain: ChainConfig) async throws -> Data")
    print("modeled on the existing native-SOL signer, reusing the same key-retrieval path.")
    print("Write the actual Swift edit by hand once you've read the anchor method's full body:")
    print(f"  sed -n '/{anchor}/,/^    }}/p' {full}")

if __name__ == "__main__":
    main()
```

```bash
python3 preview_spl_signing_helper.py ~/AetherAG-mono
```

**Step 3 — Implement (manual, guided by the anchor method body above), then verify:**

```bash
cd ~/AetherAG-mono/AGWallet
swift build 2>&1 | tail -10
swift test --filter SolanaModule 2>&1
for i in 1 2 3; do swift test --filter SolanaModule 2>&1 | tail -3; done
```

**Step 4 — Update MASTER_MILESTONES.md (Milestone 71) using the same idempotent
insert-before-anchor pattern used for Milestone 70:**

```python
#!/usr/bin/env python3
# add_milestone_71.py — same idempotent pattern as add_milestone_70_v2.py
import sys, os, difflib

ANCHOR = "## Corrections From Prior Version of This Document"
NEW_SECTION = """### Milestone 71 — SolanaModule SPL Token Balance + Send (DATE)
- [x] `KeyManagerActor.signSPLTransferPayload` — new signing helper for SPL transfers.
- [x] `SolanaModule.getBalance` — SPL path via associated-token-account + getTokenAccountBalance.
- [x] `SolanaModule.send` — SPL path via Token Program transfer instruction.
- [x] Test suite: N/N passing.

"""

def main():
    repo = sys.argv[1]
    rel = "MASTER_MILESTONES.md"
    full = os.path.join(repo, rel)
    with open(full) as f:
        content = f.read()
    if "Milestone 71" in content:
        print("Already present -- no changes (idempotent).")
        return
    if content.count(ANCHOR) != 1:
        print("!! ambiguous anchor -- abort.")
        sys.exit(1)
    new_content = content.replace(ANCHOR, NEW_SECTION + ANCHOR, 1)
    os.makedirs("./fix_preview", exist_ok=True)
    with open("./fix_preview/MASTER_MILESTONES.md", "w") as f:
        f.write(new_content)
    diff = difflib.unified_diff(content.splitlines(keepends=True),
                                  new_content.splitlines(keepends=True))
    sys.stdout.writelines(diff)

if __name__ == "__main__":
    main()
```

### A2. AetherAG — VP-resubmission-of-revoked-credential rejection test + scope narrowing

Zero test coverage currently exists for re-submitting a revoked credential; the
revocation check also checks the holder DID broadly rather than the specific credential
ID in the vp_token.

```bash
cd ~/AetherAG-mono/AetherAG
grep -rn "findBySubjectDID\|revokedAt" Sources/AetherAGMailServer/Services/VPTokenVerificationService.swift
grep -rn "findBySubjectDID\|revokedAt" Sources/AetherAGMailServer/Controllers/VerificationController.swift
```

```bash
find . -path "*/Tests/*" -iname "*Revocation*" -o -path "*/Tests/*" -iname "*VPSubmission*"
```

Once you've located the existing `VPSubmissionController`/`VPTokenVerificationService`
test files, add:
1. A test that revokes a credential, then submits a vp_token referencing it, and asserts
   the submission is rejected.
2. Tighten `VPTokenVerificationService` to extract the specific credential ID from the
   vp_token's `verifiableCredential` array before checking `revokedAt`, rather than
   checking all credentials tied to the holder DID.

```bash
cd ~/AetherAG-mono/AetherAG
swift build 2>&1 | tail -10
swift test --filter VPSubmission 2>&1
swift test --filter Revocation 2>&1
swift test 2>&1 | tail -10
```

---

## Phase B — Eliminate Remaining Workarounds

### B1. flow-swift-macos — remove `FlowActors.access` shared-singleton test race

Current fix is `swift test --no-parallel`, which is a verified workaround, not a
root-cause fix. Root cause: per-suite tests share one actor instance.

```bash
cd ~/AetherAG-mono/flow-swift-macos
grep -rn "FlowActors.access\|FlowAccessActor.shared" Sources/ Tests/ | head -30
```

```python
#!/usr/bin/env python3
# audit_flow_actor_usage.py — READ-ONLY, categorizes call sites by test file vs source file
import subprocess, sys, re
from collections import defaultdict

def main():
    repo = sys.argv[1]
    out = subprocess.run(
        ["grep", "-rln", "FlowActors.access", f"{repo}/Sources", f"{repo}/Tests"],
        capture_output=True, text=True
    ).stdout
    files = [f for f in out.splitlines() if f]
    buckets = defaultdict(list)
    for f in files:
        bucket = "test" if "/Tests/" in f else "source"
        buckets[bucket].append(f)
    print(f"Source files referencing shared singleton: {len(buckets['source'])}")
    for f in buckets["source"]:
        print(f"  {f}")
    print(f"\\nTest files referencing shared singleton: {len(buckets['test'])}")
    for f in buckets["test"]:
        print(f"  {f}")
    print("\\nNext: introduce a per-suite FlowAccessActor instance (constructor-injected,")
    print("not a global singleton) into each listed test suite's setup, and update")
    print("source call sites to accept an injected actor instead of reading the global.")

if __name__ == "__main__":
    main()
```

```bash
python3 audit_flow_actor_usage.py ~/AetherAG-mono/flow-swift-macos
```

After refactor:

```bash
cd ~/AetherAG-mono/flow-swift-macos
swift build 2>&1 | tail -10
for i in 1 2 3 4 5 6; do swift test 2>&1 | tail -3; done  # parallel, default flags now
```

### B2. AGWallet — EVMTransaction gas/nonce/block enrichment

`EVMTransaction` currently lacks fully populated `gasPrice`, `gasLimit`, `nonce`,
`blockNumber` fields on the read path (send-path already sets some via
`CodableTransaction`).

```bash
cd ~/AetherAG-mono/AGWallet
grep -n "EVMTransaction(" Sources/AetherWalletKit/Data/EVMModule/*.swift
```

Wire `eth_gasPrice`, `eth_estimateGas`, `eth_getTransactionCount` into the
`EVMIndexerClient` response mapping (the file added in Milestone 70) or into
`EVMModule.getTransactionHistory`'s post-processing step, depending on whether the
indexer already returns these fields — check the indexer response schema first:

```bash
grep -n "struct.*Response\|gasPrice\|gasUsed\|blockNumber" \
  Sources/AetherWalletKit/Data/EVMModule/EVMIndexerClient.swift
```

---

## Phase C — Production Hardening (AetherAG, currently un-started)

### C1. Rate limiting on `/oid4vci/token` and `/oid4vci/credential`

```bash
cd ~/AetherAG-mono/AetherAG
grep -rn "RateLimit\|Throttl" Sources/AetherAGMailServer/Middleware/ 2>/dev/null
ls Sources/AetherAGMailServer/Middleware/
```

If no rate-limit middleware exists yet, Vapor has no built-in rate limiter — you'll add
one backed by Redis (already in the stack per Milestone 68's `container-dev.sh` verifying
Redis connectivity):

```bash
grep -n "app.redis\|RedisConfiguration" Sources/AetherAGMailServer/Config/*.swift
```

### C2. Structured JSON logging

```bash
cd ~/AetherAG-mono/AetherAG
grep -rn "\.info(\|\.warning(\|\.error(" Sources/AetherAGMailServer/ | wc -l
grep -rln "Logger(label:" Sources/AetherAGMailServer/
```

Audit whether existing `Logger` calls pass structured metadata dictionaries (Vapor/
SwiftLog supports `logger.info("msg", metadata: [...])`) versus plain string
interpolation — replace the latter incrementally, starting with the controllers that
handle credential issuance/verification (highest audit value per NIST identity
guidance already referenced in project rules).

### C3. SECURITY.md

```bash
cat > ~/AetherAG-mono/SECURITY.md << 'EOF'
# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities privately rather than opening a public issue.

- Email: [ADD CONTACT]
- Expected response time: [ADD SLA]

## Scope

This covers AGWallet (wallet SDK), AetherAG (mail/identity client + server), and their
first-party dependencies (flow-swift-macos, solana-swift-concurrency,
web3swift-concurrency) as maintained in this repository.

## Disclosure Policy

[ADD: coordinated disclosure timeline, e.g. 90 days]
EOF
```

Fill in the bracketed fields, then:

```bash
cd ~/AetherAG-mono
git add SECURITY.md
git status
```

### C4. Load test against `/oid4vci/token`

```bash
brew install hey  # if not already installed
cd ~/AetherAG-mono/AetherAG
# start server locally first, then:
hey -n 2000 -c 50 -m POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code&pre-authorized_code=TEST" \
  http://localhost:8080/oid4vci/token
```

Target: p99 < 500ms per the existing plan. Record results before/after C1's rate
limiter lands, since rate limiting will change these numbers.

### C5. OID4VCI conformance suite (e.g. walt.id)

```bash
git clone https://github.com/walt-id/waltid-identity.git ~/waltid-conformance
```

Research walt.id's current conformance-test entrypoint (their CLI/test-runner interface
changes between releases) and point it at your locally running
`AetherAGMailServerRun` instance's issuer metadata endpoint.

---

## Phase D — App Integration

### D1. Wire AGWallet into Aether.xcworkspace UI flows

```bash
cd ~/AetherAG-mono
open Aether.xcworkspace
```

```bash
grep -rn "import AetherWalletKit" AetherAGMailClientAppShell/ AetherAG/ 2>/dev/null
```

If no import sites exist yet, this confirms wallet UI wiring hasn't started. Per the
project's Apple 2026 HIG rule, build create/restore, balance dashboard, send, and
activity flows as separate, focused SwiftUI views — not one mega-view — each backed by
a `@MainActor` view model that calls into `WalletCore` only via `async`/`await`.

### D2. CI coverage for DynamicChainConfigurator

```bash
cd ~/AetherAG-mono/AGWallet
find . -iname "*DynamicChainConfigurator*"
find . -iname "*ChainConfigurationService*Test*"
```

If no test target exists, scaffold one following the existing `EVMModuleTests.swift`
pattern (mock the underlying storage/keychain dependency, assert on save/load
round-trips and error paths).

---

## Suggested Order

Given today's Milestone 70 just landed cleanly, the lowest-risk next step is **A1 (SPL
token support)** — it's purely additive to `SolanaModule`, has no dependency on the
other repos, and follows the exact same guard-check-then-implement-then-test pattern
that just worked for EVM history. **A2 (revocation test)** is equally low-risk and
addresses an actual security completeness gap per the project's NIST-identity rule, so
it's reasonable to interleave A1 and A2 rather than strictly sequence them.
