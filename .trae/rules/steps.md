# AetherAG Next Steps

This workflow verifies repository state, identifies merge candidates safely, keeps the monorepo clean, and advances toward production without destructive writes.

Run commands one line at a time. Copy commands only, not Markdown fences or shell prompts.

## Step 1 — Baseline state

```bash
cd /Users/nicreich/AetherAG-mono; git status --short; git branch --show-current; git remote -v; git submodule status --recursive
```

Expected current concern:

- `MASTER_MILESTONES.md` is intentionally modified.
- `output/` is untracked local evidence.
- Do not commit `output/`.

## Step 2 — Fetch and inspect the superproject

```bash
cd /Users/nicreich/AetherAG-mono; git fetch --all --prune; git branch -vv; git remote show origin
```

Record:

- Current branch
- Remote default branch
- Ahead/behind state
- Any stale remote branches
- Whether the local branch tracks the expected canonical remote branch

## Step 3 — Inspect every Git repository and submodule

```bash
cd /Users/nicreich/AetherAG-mono; for d in . AetherAG flow-swift-macos solana-swift-concurrency web3swift-concurrency AGWallet; do if [ -d "$d/.git" ] || [ "$d" = . ]; then printf '\n=== %s ===\n' "$d"; git -C "$d" status --short; git -C "$d" branch --show-current; git -C "$d" fetch --all --prune; git -C "$d" branch -vv; git -C "$d" remote show origin; fi; done
```

Read all output before merging anything.

If `AGWallet` is a Swift package but not a standalone Git checkout in the current directory, this command safely skips its Git inspection.

## Step 4 — Compare an actual candidate branch before merge

Replace `CANONICAL` and `CANDIDATE` only after Step 2 and Step 3 prove their names.

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; git log --oneline --left-right CANONICAL...CANDIDATE
```

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; git log --left-right --count CANONICAL...CANDIDATE
```

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; git diff --stat CANONICAL...CANDIDATE
```

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; git diff --check CANONICAL...CANDIDATE
```

A branch is merge-eligible only when:

- Its purpose is understood
- Its commits and diff are reviewed
- It contains no generated artifacts, backups, secrets, or unrelated formatting churn
- Relevant tests pass
- It safely targets the repository’s canonical branch
- Any submodule commits were pushed before the superproject pointer changes

## Step 5 — Review the pending master roadmap edit

```bash
cd /Users/nicreich/AetherAG-mono; git diff --check; git diff -- MASTER_MILESTONES.md; git status --short
```

The expected change is a documentation reconciliation stating that `solana-swift-concurrency/MILESTONES.md` was reviewed at pinned revision `d30b8631`, while correctly preserving its remaining narrative concurrency-hardening work.

If and only if this diff contains only that reviewed change:

```bash
cd /Users/nicreich/AetherAG-mono; git add MASTER_MILESTONES.md; git diff --cached --check; git diff --cached -- MASTER_MILESTONES.md
```

Then commit and push it as a standalone documentation change:

```bash
cd /Users/nicreich/AetherAG-mono; git commit -m "docs(milestones): reconcile Solana concurrency roadmap"; git push origin HEAD
```

Do not stage `output/`.

## Step 6 — Verify local artifact handling

Inspect existing ignore policy before changing `.gitignore`:

```bash
cd /Users/nicreich/AetherAG-mono; git check-ignore -v output 2>/dev/null || true; rg -n '(^|/)(output|artifacts)/' .gitignore 2>/dev/null || true
```

If local reports are already handled by an existing convention, retain that convention. Do not add duplicate ignore entries.

## Step 7 — Run release-oriented package validation

Run each command only if the directory exists and is an independently testable Swift package.

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet; swift test
```

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; swift test
```

```bash
cd /Users/nicreich/AetherAG-mono/flow-swift-macos; swift test --parallel
```

```bash
cd /Users/nicreich/AetherAG-mono/solana-swift-concurrency; swift test
```

```bash
cd /Users/nicreich/AetherAG-mono/web3swift-concurrency; swift test
```

Do not hide failures with `|| true`. Capture the failure, determine whether it is deterministic, and fix it in the owning repository.

## Step 8 — Validate the production server build path

Use only non-production environment files, disposable databases, and non-production identity/wallet keys.

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; swift build -c release --product AetherAGMailServerRun
```

If Docker is available:

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG; docker build -f Containerfile -t aetherag-mail-server:verification .
```

Do not deploy this verification image to production.

## Step 9 — Define and certify the wallet v1 support matrix

Before adding UI or release claims, define every supported operation by chain/network:

| Operation | Bitcoin | EVM | Solana | Flow |
|---|---|---|---|---|
| Create/restore | Decide and test | Decide and test | Decide and test | Decide and test |
| Address derivation | Certify | Certify | Certify | Certify |
| Native balance | Certify | Certify | Certify | Certify |
| Token balance | N/A or define | Certify | Certify | Certify |
| Native send | Certify | Certify | Certify | Certify |
| Token send | N/A or define | Certify | Certify or gate | Certify |
| Message signing | Certify | Certify | Certify | Define/gate |
| History | Certify | Certify | Certify | Certify |
| Confirmation policy | Define | Define | Define | Define |
| Recovery/backup | Define | Define | Define | Define |

For every unsupported capability:

- Hide or disable the UI action.
- Return a clear supported-operation error.
- Document the feature gate.
- Do not market the feature as production-ready.

## Step 10 — Production gate backlog

Complete in this order:

1. Canonical branch policy and clean branch/submodule state.
2. Standardized CI release gates.
3. Solana actor/lifecycle hardening and cross-platform validation.
4. Wallet support matrix and signing/key-management security review.
5. Production-like Vapor integration testing with Postgres and Redis.
6. Rate limiting, audit logging, privacy-safe telemetry, health/readiness, and alerts.
7. Migration/backup/restore/rollback rehearsal.
8. Accessibility, localization, UI test, and client release QA.
9. Staging soak, load testing, security review, signed release candidate, controlled rollout.

## Final release gate

Do not release until all conditions are true:

- Clean Git and submodule state
- Merged, reviewed, and tested branch history
- Explicit supported-chain matrix
- No exposed experimental wallet action
- Green CI and production-like integration tests
- Verified key/credential/secret privacy controls
- Validated container, Postgres, Redis, TLS, migrations, backup, restore, and rollback
- Signed release candidate passes end-to-end wallet, identity, mail, and accessibility acceptance tests
