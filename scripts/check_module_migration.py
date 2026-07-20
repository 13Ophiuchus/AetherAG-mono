#!/usr/bin/env python3
"""
check_module_migration.py

Guardrail for AetherAG-mono modular refactors. Run at the end of every
"move types between modules" batch to catch:
  1. Consumer files referencing a moved symbol without importing its new module.
  2. Moved types missing 'public'/'package' visibility.

Usage: python3 scripts/check_module_migration.py
Update the MOVES list before each new refactor batch.
"""

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

MOVES = [
    ("Base64URL", "AetherSharedCore", ["AetherAGMailShared", "AetherAGMailServer"]),
    ("ISO8601Date", "AetherSharedCore", ["AetherAGMailShared"]),
    ("StringJSONError", "AetherSharedCore", ["AetherAGMailShared"]),
    ("toJSONDictionary", "AetherSharedCore", ["AetherAGMailShared"]),
    ("isValidDID", "AetherSharedCore", ["AetherAGMailShared"]),
    ("isValidEmail", "AetherSharedCore", ["AetherAGMailShared"]),
    ("DIDDocumentServiceProtocol", "AetherSharedProtocols", ["AetherAGMailShared"]),
    ("VerifiablePresentation", "AetherSharedIdentity", ["AetherAGMailClientApp"]),
    ("CiphertextBlobReference", "AetherSharedCore", ["AetherAGMailServer"]),
    ("ErrorDTO", "AetherSharedCore", ["AetherAGMailShared"]),
    ("VerificationRequestHandling", "AetherSharedProtocols", ["AetherAGMailServer"]),
    ("SecureStoring", "AetherSharedProtocols", ["AetherAGMailServer"]),
    ("JWTSigning", "AetherSharedProtocols", ["AetherAGMailServer"]),
    ("CredentialIssuing", "AetherSharedProtocols", ["AetherAGMailServer"]),
]

SEARCH_ROOTS = [REPO_ROOT / "AetherAG" / "Sources", REPO_ROOT / "AetherShared" / "Sources"]
EXCLUDE_DIR_PARTS = {".build", "checkouts", ".git"}


def iter_swift_files():
    for root in SEARCH_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*.swift"):
            if any(part in EXCLUDE_DIR_PARTS for part in path.parts):
                continue
            yield path


def get_imports(text):
    return set(re.findall(r"^\s*import\s+([A-Za-z0-9_]+)", text, re.MULTILINE))


def is_definition_site(text, symbol):
    patterns = [
        r"\b(public\s+|package\s+)?(enum|struct|class|protocol|actor)\s+" + re.escape(symbol) + r"\b",
        r"\bfunc\s+" + re.escape(symbol) + r"\b",
        r"\bvar\s+" + re.escape(symbol) + r"\b",
    ]
    return any(re.search(p, text) for p in patterns)


def check_visibility(new_module_files, symbol):
    problems = []
    for path in new_module_files:
        text = path.read_text(errors="ignore")
        if is_definition_site(text, symbol):
            for line in text.splitlines():
                if re.search(r"\b(enum|struct|class|protocol|actor)\s+" + re.escape(symbol) + r"\b", line):
                    if "public" not in line and "package" not in line and "open" not in line:
                        problems.append(
                            "  [visibility] {}: '{}' definition may need 'public' or 'package' -> {}".format(
                                path.relative_to(REPO_ROOT), symbol, line.strip()
                            )
                        )
    return problems


def main():
    all_files = list(iter_swift_files())
    problems = []

    for symbol, new_module, old_modules in MOVES:
        consumer_files = []
        definer_files = []

        for path in all_files:
            text = path.read_text(errors="ignore")
            if symbol not in text:
                continue
            if is_definition_site(text, symbol):
                definer_files.append(path)
                continue
            consumer_files.append((path, text))

        problems.extend(check_visibility(definer_files, symbol))

        for path, text in consumer_files:
            imports = get_imports(text)
            if new_module in imports:
                continue
            stale_old_imports = [m for m in old_modules if m in imports]
            if stale_old_imports and new_module not in imports:
                problems.append(
                    "  [check-import] {}: uses '{}' via old import(s) {} - confirm '{}' is "
                    "reachable transitively, or add 'import {}' explicitly.".format(
                        path.relative_to(REPO_ROOT), symbol, stale_old_imports, new_module, new_module
                    )
                )
            elif not imports.intersection({new_module} | set(old_modules)):
                problems.append(
                    "  [missing-import] {}: uses '{}' but imports neither '{}' nor {}.".format(
                        path.relative_to(REPO_ROOT), symbol, new_module, old_modules
                    )
                )

    if problems:
        print("Found {} potential module-migration issue(s):\n".format(len(problems)))
        print("\n".join(sorted(set(problems))))
        print(
            "\nNext steps:\n"
            "  1. Add 'public' (or 'package') to any flagged definition.\n"
            "  2. Add the missing 'import <NewModule>' to flagged consumer files.\n"
            "  3. Confirm the consuming target's Package.swift lists the new module\n"
            "     as a dependency (.product(name: \"<NewModule>\", package: \"AetherShared\")).\n"
            "  4. Re-run this script, then 'swift build' and 'swift test' for both\n"
            "     AetherAG and AetherShared before committing.\n"
        )
        return 1

    print("No module-migration issues found for the configured MOVES list.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
