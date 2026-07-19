# AetherShared Migration Milestones

Incremental extraction plan for introducing `AetherShared` as a foundation
package beneath `AGWallet` and `AetherAG`. Follow phases in order. Do not
skip discovery steps — paste their output back before proceeding to the
next numbered step in that phase.

---

## Phase 0: Freeze boundaries

- [ ] 0.1 Confirm current package graph (discovery — paste output before continuing)

```bash
cd /Users/nicreich/AetherAG-mono
grep -n 'package(path' AetherAG/Package.swift AGWallet/Package.swift 2>/dev/null
```

- [ ] 0.2 Create a dependency-rule doc stub recording the frozen boundary

```bash
cd /Users/nicreich/AetherAG-mono
cat << 'EOF' > AetherShared-DEPENDENCY-RULES.md
# AetherShared Dependency Rules

- AetherSharedCore: no internal dependencies.
- AetherSharedIdentity: depends only on AetherSharedCore.
- AetherSharedProtocols: depends on AetherSharedCore + AetherSharedIdentity.
- AetherShared must NEVER depend on AGWallet, AetherAG, Vapor, Flow, or BigInt.
- AGWallet and AetherAG may depend on AetherShared targets, never the reverse.
EOF
cat AetherShared-DEPENDENCY-RULES.md
```

- [ ] 0.3 Commit the frozen boundary doc

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared-DEPENDENCY-RULES.md MIGRATION_MILESTONES.md
git status
git commit -m "docs: freeze AetherShared dependency boundaries and add migration milestones"
git push origin main
```

---

## Phase 1: Inventory and classify code

- [ ] 1.1 List all files in AetherAGMailShared (discovery — paste output before continuing)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared -type f -name '*.swift' | sort
```

- [ ] 1.2 Find files that import Vapor, Flow, or BigInt (keep-in-place candidates; discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rl -E '^import (Vapor|Flow|BigInt)' AetherAG/Sources/AetherAGMailShared
```

- [ ] 1.3 Find pure Codable/value-type candidates (move-now candidates; discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rl -E 'struct .*: *Codable|enum .*: *Codable|struct .*: *Sendable' AetherAG/Sources/AetherAGMailShared
```

- [ ] 1.4 Write the classification results to a tracking CSV using python3

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import csv, pathlib

root = pathlib.Path('AetherAG/Sources/AetherAGMailShared')
files = sorted(str(p) for p in root.rglob('*.swift'))

with open('AetherShared-migration-inventory.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['file', 'bucket', 'notes'])
    for file in files:
        writer.writerow([file, 'UNCLASSIFIED', ''])
print(f'Wrote {len(files)} rows to AetherShared-migration-inventory.csv')
"
cat AetherShared-migration-inventory.csv
```

- [ ] 1.5 Commit the inventory

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared-migration-inventory.csv
git commit -m "docs: add AetherShared migration file inventory"
git push origin main
```

---

## Phase 2: Create the new package skeleton

- [ ] 2.1 Create the AetherShared directory tree

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedCore
mkdir -p AetherShared/Sources/AetherSharedIdentity
mkdir -p AetherShared/Sources/AetherSharedProtocols
mkdir -p AetherShared/Sources/AetherSharedTestSupport
mkdir -p AetherShared/Tests/AetherSharedCoreTests
mkdir -p AetherShared/Tests/AetherSharedIdentityTests
mkdir -p AetherShared/Tests/AetherSharedProtocolsTests
find AetherShared -type d | sort
```

- [ ] 2.2 Create placeholder source files so empty targets compile

```bash
cd /Users/nicreich/AetherAG-mono
cat << 'EOF' > AetherShared/Sources/AetherSharedCore/AetherSharedCore.swift
// AetherSharedCore — foundation layer, no internal dependencies.
public enum AetherSharedCore {
    public static let version = "0.1.0"
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedIdentity/AetherSharedIdentity.swift
// AetherSharedIdentity — depends only on AetherSharedCore.
import AetherSharedCore

public enum AetherSharedIdentity {
    public static let version = "0.1.0"
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/AetherSharedProtocols.swift
// AetherSharedProtocols — protocol boundaries only, no concrete implementations.
import AetherSharedCore
import AetherSharedIdentity

public enum AetherSharedProtocols {
    public static let version = "0.1.0"
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedTestSupport/AetherSharedTestSupport.swift
// AetherSharedTestSupport — fixtures and spies for AetherShared consumers.
import AetherSharedCore
import AetherSharedIdentity
import AetherSharedProtocols

public enum AetherSharedTestSupport {
    public static let version = "0.1.0"
}
EOF
find AetherShared/Sources -type f | sort
```

- [ ] 2.3 Create Package.swift with tools version 6.0 (matching AetherAG)

```bash
cd /Users/nicreich/AetherAG-mono
cat << 'EOF' > AetherShared/Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherShared",
    platforms: [
        .macOS(.v14),
        .iOS(.v18),
    ],
    products: [
        .library(name: "AetherSharedCore", targets: ["AetherSharedCore"]),
        .library(name: "AetherSharedIdentity", targets: ["AetherSharedIdentity"]),
        .library(name: "AetherSharedProtocols", targets: ["AetherSharedProtocols"]),
        .library(name: "AetherSharedTestSupport", targets: ["AetherSharedTestSupport"]),
    ],
    targets: [
        .target(
            name: "AetherSharedCore",
            path: "Sources/AetherSharedCore"
        ),
        .target(
            name: "AetherSharedIdentity",
            dependencies: ["AetherSharedCore"],
            path: "Sources/AetherSharedIdentity"
        ),
        .target(
            name: "AetherSharedProtocols",
            dependencies: ["AetherSharedCore", "AetherSharedIdentity"],
            path: "Sources/AetherSharedProtocols"
        ),
        .target(
            name: "AetherSharedTestSupport",
            dependencies: ["AetherSharedCore", "AetherSharedIdentity", "AetherSharedProtocols"],
            path: "Sources/AetherSharedTestSupport"
        ),
        .testTarget(
            name: "AetherSharedCoreTests",
            dependencies: ["AetherSharedCore"],
            path: "Tests/AetherSharedCoreTests"
        ),
        .testTarget(
            name: "AetherSharedIdentityTests",
            dependencies: ["AetherSharedIdentity", "AetherSharedTestSupport"],
            path: "Tests/AetherSharedIdentityTests"
        ),
        .testTarget(
            name: "AetherSharedProtocolsTests",
            dependencies: ["AetherSharedProtocols", "AetherSharedTestSupport"],
            path: "Tests/AetherSharedProtocolsTests"
        ),
    ]
)
EOF
cat AetherShared/Package.swift
```

- [ ] 2.4 Add minimal placeholder test files so test targets build

```bash
cd /Users/nicreich/AetherAG-mono
cat << 'EOF' > AetherShared/Tests/AetherSharedCoreTests/AetherSharedCoreTests.swift
import Testing
@testable import AetherSharedCore

@Test func versionIsSet() {
    #expect(!AetherSharedCore.version.isEmpty)
}
EOF
cat << 'EOF' > AetherShared/Tests/AetherSharedIdentityTests/AetherSharedIdentityTests.swift
import Testing
@testable import AetherSharedIdentity

@Test func versionIsSet() {
    #expect(!AetherSharedIdentity.version.isEmpty)
}
EOF
cat << 'EOF' > AetherShared/Tests/AetherSharedProtocolsTests/AetherSharedProtocolsTests.swift
import Testing
@testable import AetherSharedProtocols

@Test func versionIsSet() {
    #expect(!AetherSharedProtocols.version.isEmpty)
}
EOF
find AetherShared/Tests -type f | sort
```

- [ ] 2.5 Build the new package standalone to verify the skeleton compiles

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build
swift test
```

- [ ] 2.6 Commit the package skeleton

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared
git status
git commit -m "feat: bootstrap AetherShared package skeleton (Core/Identity/Protocols/TestSupport)"
git push origin main
```

---

## Phase 3: Add package dependencies without moving code yet

- [ ] 3.1 Backup AetherAG/Package.swift before editing

```bash
cd /Users/nicreich/AetherAG-mono
cp AetherAG/Package.swift AetherAG/Package.swift.bak
```

- [ ] 3.2 Show current dependencies array for reference (discovery — paste output before editing)

```bash
cd /Users/nicreich/AetherAG-mono
grep -n -A20 'dependencies: \[' AetherAG/Package.swift | head -30
```

- [ ] 3.3 Add AetherShared as a local path dependency using python3 (idempotent insert)

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import pathlib
p = pathlib.Path('AetherAG/Package.swift')
text = p.read_text()
marker = '.package(path: \"../AGWallet\"),'
addition = '    .package(path: \"../AetherShared\"),'
if addition not in text:
    text = text.replace(marker, marker + chr(10) + addition, 1)
    p.write_text(text)
    print('Inserted AetherShared dependency.')
else:
    print('AetherShared dependency already present — no change made.')
"
grep -n 'AetherShared\|AGWallet' AetherAG/Package.swift
```

- [ ] 3.4 Build AetherAG to confirm the dependency resolves without any target wiring yet

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
```

- [ ] 3.5 Commit the dependency wiring

```bash
cd /Users/nicreich/AetherAG-mono
rm -f AetherAG/Package.swift.bak
git add AetherAG/Package.swift
git diff --cached AetherAG/Package.swift
git commit -m "chore: add AetherShared as a local package dependency of AetherAG"
git push origin main
```

---

## Phase 4: Migrate Core first

- [x] 4.1 Locate HTTPMethod.swift and view its contents (discovery — paste output before moving)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared -iname 'HTTPMethod.swift'
cat AetherAG/Sources/AetherAGMailShared/Network/HTTPMethod.swift 2>/dev/null
```

- [x] 4.2 Move HTTPMethod.swift into AetherSharedCore

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedCore/Network
git mv AetherAG/Sources/AetherAGMailShared/Network/HTTPMethod.swift AetherShared/Sources/AetherSharedCore/Network/HTTPMethod.swift
ls AetherShared/Sources/AetherSharedCore/Network/
```

- [x] 4.3 Find any remaining references to HTTPMethod in AetherAG that need an import added (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rl 'HTTPMethod' AetherAG/Sources
```

- [x] 4.4 Add the AetherSharedCore product dependency to AetherAGMailShared target using python3

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import pathlib
p = pathlib.Path('AetherAG/Package.swift')
text = p.read_text()
marker = 'name: \"AetherAGMailShared\",\n      dependencies: ['
addition = '\n        .product(name: \"AetherSharedCore\", package: \"AetherShared\"),'
if 'AetherSharedCore' not in text:
    idx = text.find(marker)
    if idx == -1:
        print('Marker not found — manual edit required.')
    else:
        insert_at = idx + len(marker)
        text = text[:insert_at] + addition + text[insert_at:]
        p.write_text(text)
        print('Inserted AetherSharedCore product dependency.')
else:
    print('AetherSharedCore dependency already present — no change made.')
"
grep -n -B2 -A5 'name: \"AetherAGMailShared\"' AetherAG/Package.swift | head -20
```

- [x] 4.5 Add the import statement to any file that used HTTPMethod (manual edit — paste grep results from 4.3 first)

```bash
# After confirming affected files from step 4.3, add the import to each one, e.g.:
# sed -i '' '1i\
# import AetherSharedCore\
# ' <path-to-affected-file>.swift
echo "Run this only after identifying affected files from step 4.3"
```

- [x] 4.6 Build AetherShared and AetherAG, then run Core tests

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build
swift test --filter AetherSharedCoreTests

cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
```

- [x] 4.7 Commit the Core migration batch

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared AetherAG
git status
git commit -m "refactor: move HTTPMethod into AetherSharedCore"
git push origin main
```

---


> **Note (Phase 4 actual execution):** `HTTPMethod.swift` on disk actually contained merged content — `HTTPMethod`, `APIClient`, `APIClientError`, and `EmptyRequestBody` — so the moved/renamed file is `AetherSharedCore/Network/APIClient.swift`, not `HTTPMethod.swift`. Two real consumers were updated (`AetherAGMailShared/Network/VerificationAPI.swift`, `AetherAGMailClientCore/Networking/VerificationAPI.swift`) with `import AetherSharedCore`. Full build + 51 tests / 34 suites passed. Committed as AetherAG@e0b08c3, AetherAG-mono@6631280/b9f2f2f.

---

## Phase 5: Migrate identity models

- [x] 5.1 List all Credentials DTO files (discovery — paste output before moving)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared/Credentials -type f -name '*.swift' | sort
```

- [x] 5.2 Check each Credentials file for disallowed imports before moving (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -l -E '^import (Vapor|Flow|BigInt)' AetherAG/Sources/AetherAGMailShared/Credentials/*.swift
```

- [x] 5.3 Move all Credentials DTOs into AetherSharedIdentity (only run after confirming 5.2 output is empty)

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedIdentity/Credentials
git mv AetherAG/Sources/AetherAGMailShared/Credentials/*.swift AetherShared/Sources/AetherSharedIdentity/Credentials/
ls AetherShared/Sources/AetherSharedIdentity/Credentials/
```

**Note (2026-07-13):** During 5.3 execution, discovered that `VerifiableCredential.swift` depended on `DynamicCodingKeys` (previously in `AetherAGMailShared/Utilities/`), which was not listed in the original discovery scan. Resolved by relocating `DynamicCodingKeys` into `AetherSharedCore` (Foundation-only) and changing its access level from `package` to `public` so it remains visible across package boundaries. Also added generic `DynamicKeyedArray<Element>` / `KeyedArrayGroup<Element>` decoding helpers to `AetherSharedCore` for dynamic-key JSON array claims, documented in `AetherShared-DEPENDENCY-RULES.md`. Full test suite (51 tests / 34 suites) passed after migration; all 3 repos (`AetherShared`, `AetherAG`, `AetherAG-mono`) synced across their correct default branches (`main`, `master`, `main` respectively).

- [x] 5.4 List Issuance DTO files (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared/Issuance -type f -name '*.swift' | sort
```

- [x] 5.5 Check Issuance files for disallowed imports (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -l -E '^import (Vapor|Flow|BigInt)' AetherAG/Sources/AetherAGMailShared/Issuance/*.swift
```

- [x] 5.6 Move Issuance DTOs into AetherSharedIdentity (split plain files vs. Vapor-coupled files)

**Note (2026-07-13):** Of 7 Issuance files (including `Dev/` subfolder, which the top-level `*.swift` glob missed on first pass — remember to scan subfolders separately), 2 were Foundation-only and moved outright (`IssuanceAccessTokenClaimsDTO.swift`, `DevSeedIssuanceSessionRequestDTO.swift`). The remaining 5 (`IssuerMetadataDTO`, `TokenRequestDTO`, `TokenResponseDTO`, `DevTokenRequestDTO`, `DevSeedIssuanceSessionResponseDTO`) imported `Vapor` for `Content` conformance only — split pattern applied: plain `Codable, Sendable` struct moved to `AetherSharedIdentity/Issuance/`, thin `extension X: @retroactive Content {}` left behind in `AetherAGMailShared/Issuance/` (importing both `Vapor` and `AetherSharedIdentity`). Also `AetherAG` is a git submodule and `AetherShared` is a plain top-level dir, so `git mv` cannot cross that boundary — use plain `mv` + separate `git add` in each repo instead. Two additional lessons: (1) structs split this way must explicitly declare `Codable` (or hand-write `init(from:)`/`encode(to:)`) in their own file, since Swift cannot synthesize `Codable` from a conformance declared in an external extension; (2) several consumers (`IssuanceAccessTokenPayload.swift`, `IssuerController.swift`, `OID4VCIService.swift`, plus test files `SharedDTORoundTripTests.swift`/`SharedContractsTests.swift`) imported only `AetherAGMailShared` and needed a direct `AetherSharedIdentity` import added once the DTOs moved out. Full shared (8/8) and server (32/32) test suites passed after migration; `AetherAG` submodule and `AetherAG-mono` parent both pushed (`master` c6808a8, `main` ad06c7e).

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedIdentity/Issuance
ls AetherShared/Sources/AetherSharedIdentity/Issuance/
```

- [x] 5.7 List VC and Verification files (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared/VC AetherAG/Sources/AetherAGMailShared/Verification -type f -name '*.swift' 2>/dev/null | sort
```

- [x] 5.8 Check VC/Verification files for disallowed imports (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -l -E '^import (Vapor|Flow|BigInt)' AetherAG/Sources/AetherAGMailShared/VC/*.swift AetherAG/Sources/AetherAGMailShared/Verification/*.swift 2>/dev/null
```

- [x] 5.9 Move VC/Verification pure model files (split plain files vs. Vapor-coupled files)

**Note (2026-07-13):** The top-level `VC/*.swift` glob matched nothing (`VCJSONCanonicalizer.swift` lives under `VC/Utilities/`) — same subfolder-glob gap as the Issuance batch; a full recursive `find` + per-file `import` scan is now the required first step, not the top-level glob. `Verification/VerificationStatus.swift` actually declares 5 types (`VerificationStatus`, `VerificationRecord`, `VerificationCreateRequest`, `VerificationSubmissionRequest`, `VerificationDecision`), and `VerificationSubmissionRequest` referenced a previously-unlisted type `PresentationSubmission`, physically defined in `Presentation/PresentationSubmissionDTO.swift` (filename says `...DTO`, but the actual struct inside is named `PresentationSubmission`, plus a second type `InputDescriptorMapping` — filenames do not reliably indicate contained type names, always grep the body). Both had to move together as a dependency chain. Final split: 4 plain Foundation-only files moved outright (`VCJSONCanonicalizer`, `VerificationPolicy`, `VerificationStatus`+4 nested types, `PresentationSubmissionDTO`); 3 Vapor-`Content`-only files split (`VerificationStatusResponse`, `VerificationResultDTO`, `VerificationRequestDTO`) using the same plain-struct + `@retroactive Content` extension pattern as Issuance. 9 non-test consumers and 5 test files (2 in `AetherAGMailSharedTests`, 3 in `AetherAGMailServerTests`) needed `AetherSharedIdentity` imports added; also fixed a pre-existing duplicate `import AetherAGMailShared` line found in `VerificationController.swift`. Full shared (8/8) and server (32/32) test suites passed after migration; `AetherAG` submodule and `AetherAG-mono` parent both pushed (`master` b875bc4, `main` 34a9e34).

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedIdentity/VC
mkdir -p AetherShared/Sources/AetherSharedIdentity/Verification
find AetherShared/Sources/AetherSharedIdentity -type f | sort
```

- [x] 5.10 List DID files and flag which are model vs service (discovery — service files like DIDResolver should NOT move yet)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared/DID -type f -name '*.swift' | sort
grep -l -E 'class .*Resolver|protocol .*Resolving|func .*resolve' AetherAG/Sources/AetherAGMailShared/DID/*.swift 2>/dev/null
```

**Note (2026-07-19):** Found 3 DID files (`DIDResolver.swift`, `Documents/DIDDocumentService.swift`, `Documents/DIDDocumentServiceProtocol.swift`); `Methods/` and `Models/` subfolders are empty. All 3 are service/protocol code, not pure models — nothing moved in Phase 5. `DIDDocumentServiceProtocol.swift` deferred to Phase 6 protocol extraction.

- [x] 5.11 Find every file across AetherAG referencing the moved types (discovery — paste output before adding imports)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rl -E 'VerifiableCredential|CredentialDisplayDTO|CredentialSubjectDTO|CredentialRequestDTO|CredentialResponseDTO|IssuerMetadataDTO|TokenRequestDTO|TokenResponseDTO' AetherAG/Sources
```

**Note (2026-07-19):** All 26 real consumer files (excluding `.build/` artifacts) already had `import AetherSharedIdentity` present from earlier Phase 5 batches — confirmed via `AetherShared-phase5-consumers.csv`. No manual import edits were needed for 5.14.

- [x] 5.12 Add AetherSharedIdentity product dependency to AetherAGMailShared, AetherAGMailClientCore, and AetherAGMailServer using python3

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import pathlib
p = pathlib.Path('AetherAG/Package.swift')
text = p.read_text()
targets = ['AetherAGMailShared', 'AetherAGMailClientCore', 'AetherAGMailServer']
for t in targets:
    marker = f'name: \"{t}\",\n      dependencies: ['
    idx = text.find(marker)
    if idx == -1:
        print(f'{t}: marker not found — manual edit required.')
        continue
    check_window = text[idx: idx + 800]
    if 'AetherSharedIdentity' in check_window:
        print(f'{t}: AetherSharedIdentity already present — skipped.')
        continue
    insert_at = idx + len(marker)
    addition = '\n        .product(name: \"AetherSharedIdentity\", package: \"AetherShared\"),'
    text = text[:insert_at] + addition + text[insert_at:]
    print(f'{t}: inserted AetherSharedIdentity dependency.')
pathlib.Path('AetherAG/Package.swift').write_text(text)
"
grep -n 'AetherSharedIdentity' AetherAG/Package.swift
```

- [x] 5.13 Build AetherShared and AetherAG, run identity tests

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build
swift test --filter AetherSharedIdentityTests

cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
```

- [x] 5.14 If build fails on missing imports, add `import AetherSharedIdentity` to each affected file found in step 5.11 (manual edit per file, then rebuild)

```bash
# For each file from step 5.11 output, run (replace <file> with actual path):
# python3 -c "
# import pathlib
# p = pathlib.Path('<file>')
# text = p.read_text()
# if 'import AetherSharedIdentity' not in text:
#     p.write_text('import AetherSharedIdentity\n' + text)
# "
echo "Run the commented python3 snippet per affected file from step 5.11"
```

- [ ] 5.15 Commit the identity models migration batch

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared AetherAG
git status
git commit -m "refactor: move Credentials/Issuance/VC/Verification DTOs into AetherSharedIdentity"
git push origin main
```

---

## Phase 6: Extract protocols

- [ ] 6.1 Search for existing protocol definitions related to DID/credential/signing/storage (discovery — paste output before drafting protocols)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rn -E 'protocol .*(Resolving|Issuing|Verifying|Signing|Storing|Sending)' AetherAG/Sources AGWallet/Sources 2>/dev/null
```

- [ ] 6.2 Create protocol stub files in AetherSharedProtocols based on discovery results

```bash
cd /Users/nicreich/AetherAG-mono
mkdir -p AetherShared/Sources/AetherSharedProtocols/DID
mkdir -p AetherShared/Sources/AetherSharedProtocols/Credentials
mkdir -p AetherShared/Sources/AetherSharedProtocols/Security
mkdir -p AetherShared/Sources/AetherSharedProtocols/Storage
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/DID/DIDResolving.swift
import AetherSharedIdentity

public protocol DIDResolving: Sendable {
    func resolve(did: String) async throws -> Data
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/Credentials/CredentialIssuing.swift
import AetherSharedIdentity

public protocol CredentialIssuing: Sendable {
    func issue(request: Data) async throws -> Data
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/Credentials/CredentialVerifying.swift
import AetherSharedIdentity

public protocol CredentialVerifying: Sendable {
    func verify(credential: Data) async throws -> Bool
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/Security/JWTSigning.swift
public protocol JWTSigning: Sendable {
    func sign(claims: Data) async throws -> String
}
EOF
cat << 'EOF' > AetherShared/Sources/AetherSharedProtocols/Storage/SecureStoring.swift
public protocol SecureStoring: Sendable {
    func store(key: String, value: Data) async throws
    func retrieve(key: String) async throws -> Data?
}
EOF
find AetherShared/Sources/AetherSharedProtocols -type f | sort
```

- [ ] 6.3 Build AetherShared to verify protocol stubs compile

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build
swift test --filter AetherSharedProtocolsTests
```

- [ ] 6.4 Add AetherSharedProtocols dependency to AetherAGMailClientCore and AetherAGMailServer using python3

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import pathlib
p = pathlib.Path('AetherAG/Package.swift')
text = p.read_text()
targets = ['AetherAGMailClientCore', 'AetherAGMailServer']
for t in targets:
    marker = f'name: \"{t}\",\n      dependencies: ['
    idx = text.find(marker)
    if idx == -1:
        print(f'{t}: marker not found — manual edit required.')
        continue
    check_window = text[idx: idx + 800]
    if 'AetherSharedProtocols' in check_window:
        print(f'{t}: AetherSharedProtocols already present — skipped.')
        continue
    insert_at = idx + len(marker)
    addition = '\n        .product(name: \"AetherSharedProtocols\", package: \"AetherShared\"),'
    text = text[:insert_at] + addition + text[insert_at:]
    print(f'{t}: inserted AetherSharedProtocols dependency.')
pathlib.Path('AetherAG/Package.swift').write_text(text)
"
grep -n 'AetherSharedProtocols' AetherAG/Package.swift
```

- [ ] 6.5 Build AetherAG to confirm protocol wiring resolves

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
```

- [ ] 6.6 Commit the protocols extraction batch

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared AetherAG
git status
git commit -m "feat: introduce AetherSharedProtocols boundary types (DID/Credential/JWT/Storage)"
git push origin main
```

---

## Phase 7: Slim AetherAGMailShared

- [ ] 7.1 Show remaining file count and imports in AetherAGMailShared (discovery — paste output before further edits)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources/AetherAGMailShared -type f -name '*.swift' | wc -l
grep -rh '^import' AetherAG/Sources/AetherAGMailShared --include='*.swift' | sort | uniq -c | sort -rn
```

- [ ] 7.2 Build full AetherAG to confirm the slimmed shared module still compiles

```bash
cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
swift test 2>&1 | tail -50
```

- [ ] 7.3 Commit the slimming checkpoint (only if 7.1/7.2 show meaningful reduction; otherwise skip and revisit after more Phase 5/6 batches)

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherAG
git status
git commit -m "refactor: slim AetherAGMailShared after AetherShared extraction"
git push origin main
```

---

## Phase 8: Evaluate AGWallet adoption

- [ ] 8.1 Search AGWallet for candidate reuse of shared identity/error/signing types (discovery — paste output before deciding)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rn -E 'enum .*Error|protocol .*Signing|struct .*DID|struct .*Credential' AGWallet/Sources 2>/dev/null
```

- [ ] 8.2 If adoption is justified, add AetherShared as a local dependency of AGWallet (only run after reviewing 8.1)

```bash
cd /Users/nicreich/AetherAG-mono
cp AGWallet/Package.swift AGWallet/Package.swift.bak
python3 -c "
import pathlib
p = pathlib.Path('AGWallet/Package.swift')
text = p.read_text()
if 'AetherShared' not in text:
    marker = 'dependencies: ['
    idx = text.find(marker)
    insert_at = idx + len(marker)
    addition = '\n        .package(path: \"../AetherShared\"),'
    text = text[:insert_at] + addition + text[insert_at:]
    p.write_text(text)
    print('Inserted AetherShared dependency into AGWallet/Package.swift.')
else:
    print('AetherShared dependency already present in AGWallet — no change made.')
"
grep -n 'AetherShared' AGWallet/Package.swift
```

- [ ] 8.3 Build AGWallet to confirm the new dependency resolves

```bash
cd /Users/nicreich/AetherAG-mono/AGWallet
swift build
swift test
```

- [ ] 8.4 Commit AGWallet adoption decision (either the wiring, or a documented decision not to adopt yet)

```bash
cd /Users/nicreich/AetherAG-mono
rm -f AGWallet/Package.swift.bak
git add AGWallet
git status
git commit -m "chore: evaluate/wire AetherShared adoption in AGWallet"
git push origin main
```

---

## Phase 9: Clean test support in parallel

- [ ] 9.1 List existing test-support targets for reference (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
find AetherAG/Sources -maxdepth 1 -iname '*TestSupport*' -type d | sort
```

- [ ] 9.2 List fixtures/spies referencing newly moved identity types (discovery — paste output before moving)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rl -E 'VerifiableCredential|CredentialDisplayDTO|IssuerMetadataDTO' AetherAG/Sources/SharedTestSupport AetherAG/Sources/ClientCoreTestSupport AetherAG/Sources/ServerTestSupport AetherAG/Sources/ClientAppTestSupport 2>/dev/null
```

- [ ] 9.3 Move identified fixture files into AetherSharedTestSupport (adjust paths based on 9.2 output before running)

```bash
# Example pattern — replace <fixture-file> with actual paths from step 9.2:
# mkdir -p AetherShared/Sources/AetherSharedTestSupport/Credentials
# git mv AetherAG/Sources/SharedTestSupport/<fixture-file>.swift AetherShared/Sources/AetherSharedTestSupport/Credentials/
echo "Run git mv per fixture file identified in step 9.2"
```

- [ ] 9.4 Build AetherShared and AetherAG test targets

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build
swift test

cd /Users/nicreich/AetherAG-mono/AetherAG
swift build
swift test 2>&1 | tail -50
```

- [ ] 9.5 Commit the test-support migration batch

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared AetherAG
git status
git commit -m "refactor: move identity fixtures/spies into AetherSharedTestSupport"
git push origin main
```

---

## Phase 10: Hardening and cleanup

- [ ] 10.1 Audit public vs internal access levels across AetherShared (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rn -E '^(public|internal|private|struct|enum|class|protocol) ' AetherShared/Sources | grep -v '^.*public ' | sort
```

- [ ] 10.2 Check for missing Sendable conformance on moved types (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -rln -E 'struct |enum |class ' AetherShared/Sources | xargs grep -L 'Sendable' 2>/dev/null
```

- [ ] 10.3 Verify the dependency graph remains acyclic (discovery)

```bash
cd /Users/nicreich/AetherAG-mono
grep -n 'package(path' AetherShared/Package.swift AGWallet/Package.swift AetherAG/Package.swift 2>/dev/null
```

- [ ] 10.4 Run full build and test suite across all three packages

```bash
cd /Users/nicreich/AetherAG-mono/AetherShared
swift build && swift test

cd /Users/nicreich/AetherAG-mono/AGWallet
swift build && swift test

cd /Users/nicreich/AetherAG-mono/AetherAG
swift build && swift test 2>&1 | tail -80
```

- [ ] 10.5 Update AGWallet/AetherAG MILESTONES.md to reflect the extraction milestone using python3

```bash
cd /Users/nicreich/AetherAG-mono
python3 -c "
import pathlib, datetime
note = f'\n- [x] AetherShared extraction complete ({datetime.date.today().isoformat()}): Core/Identity/Protocols packages live, AetherAGMailShared slimmed, AGWallet adoption evaluated.\n'
for path in ['AGWallet/MILESTONES.md', 'AetherAG/MILESTONES.md']:
    p = pathlib.Path(path)
    if p.exists():
        text = p.read_text()
        if 'AetherShared extraction complete' not in text:
            p.write_text(text + note)
            print(f'{path}: appended completion note.')
        else:
            print(f'{path}: note already present — skipped.')
    else:
        print(f'{path}: not found.')
"
```

- [ ] 10.6 Final commit closing out the migration

```bash
cd /Users/nicreich/AetherAG-mono
git add AetherShared AGWallet AetherAG
git status
git commit -m "chore: harden AetherShared (access levels, Sendable, docs) and close out migration"
git push origin main
```

<!-- milestone:update:56bd7ce924 -->
## Milestone 12: AsyncMutex shutdown race + DID module extraction

Fixed by replacing the actor with an explicit AsyncMutex (continuation
waiter queue) and awaiting asyncShutdown() synchronously within the
locked critical section. Verified with 20 consecutive full-suite runs
against live Postgres: 51/51 passing every time. Builds clean under
-strict-concurrency=complete.

Also extracted the DID identity module (DIDDocument, DIDService,
DIDKeyFormatter, DIDIdentifier, VerificationMethod) into
AetherSharedIdentity, with DID API, Verification Persistence, and
Issuer JWS kid Consistency test suites passing.

AGWallet build verified clean (189/189) alongside these changes.

Tagged as milestone-12-async-mutex-shutdown (ca6d25c).

---

## Phase 6: Migrate remaining shared model records + protocol contracts

- [x] 6.1 Move `CredentialRecord`, `IssuanceSessionRecord`, `IssuanceSession` into `AetherSharedIdentity`

**Note (2026-07-19):** Removed duplicate local copies from `AetherAGMailServer/Models` and `Repositories` (`IssuanceSession.swift`, `IssuanceSessionRecord.swift`, `CredentialRecord.swift`, `VerificationRequestRecord.swift`) once canonical versions existed in `AetherSharedIdentity`. 8 consumer files needed `import AetherSharedIdentity` added after the local types disappeared from scope: `IssuanceSessionRepository.swift`, `InMemoryIssuanceSessionRepository.swift`, `IssuanceSessionRepositoryProtocol.swift`, `OID4VCIAcceptanceCriteriaTests.swift`, `DevIssuanceSeed.swift`, `CredentialRepositoryProtocol.swift`, `SQLCredentialRepository.swift`, `InMemoryCredentialRepository.swift`.

- [x] 6.2 Restore Vapor `Content` conformance for `VerificationRequestRecord` in the server module

**Note (2026-07-19):** `VerificationRequestRecord` lost its `Content` conformance during the move because `AetherSharedIdentity` has no Vapor dependency (by design, per `AetherShared-DEPENDENCY-RULES.md`). Compile broke at `VerificationController.swift` (`get(_:use:)` requires `AsyncResponseEncodable`). Fixed with a thin extension file in the server module, same split pattern as Phase 5's Issuance/VC DTOs:

    // AetherAG/Sources/AetherAGMailServer/Repositories/VerificationRequestRecord+Content.swift
    import Vapor
    import AetherSharedIdentity

    extension VerificationRequestRecord: @retroactive Content {}

The `@retroactive` annotation was required to silence Swift's cross-module-conformance warning (conforming an imported type to imported protocols outside either module).

- [x] 6.3 Full build + test verification

Ran from `AetherAG/`:

    swift build   # Build complete! (12.46s), zero warnings after @retroactive fix
    swift test    # Test run with 51 tests in 34 suites passed after 0.380 seconds

All 51 tests across 34 suites passed with no regressions. Phase 6 closes out the model-record extraction; remaining open items are Phase 5.10/5.11 (DID service-layer files, deferred as service-not-model) and formal protocol contracts in `AetherSharedProtocols` (`DIDDocumentMaking`, `CredentialIssuing`, `VerificationRequestHandling`, `JWTSigning`, `SecureStoring`) which were scaffolded but not yet wired to concrete implementations.
