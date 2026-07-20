#!/usr/bin/env python3
from pathlib import Path

base = Path("/Users/nicreich/AetherAG-mono/AetherAG/Sources/AetherAGMailServer")
targets = [
    base / "Support/PassthroughAttestationVerifier.swift",
    base / "Extensions/CredentialRepository+Application.swift",
    base / "Extensions/Request+Repositories.swift",
]

IMPORT_LINE = "import AetherSharedProtocols"

for path in targets:
    text = path.read_text()
    if IMPORT_LINE in text:
        print(f"SKIP (already present): {path}")
        continue

    lines = text.splitlines(keepends=True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1

    lines.insert(insert_at, IMPORT_LINE + "\n")
    path.write_text("".join(lines))
    print(f"UPDATED: {path}")
