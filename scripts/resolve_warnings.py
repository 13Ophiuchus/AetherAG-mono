#!/usr/bin/env python3
"""
resolve_warnings.py

Diagnoses and resolves Swift compiler warnings surfaced during
`swift build` for the AetherAG-mono monorepo.

Strategy:
  - All warnings currently originate from vendored/patched third-party
    packages (solana-swift-patched, web3swift-patched), NOT AetherAG's
    own source. Editing vendor source directly is fragile (breaks future
    upstream patch merges), so this script instead:
      1. Parses the build log to confirm warning origin (package + file).
      2. Reports a clear diagnosis (counts, files, messages).
      3. Optionally patches the vendored package's own Package.swift to
         suppress warnings at the target level via `-suppress-warnings`
         unsafeFlags (Swift build setting), scoped ONLY to the specific
         target(s) that produced warnings.
      4. Leaves AetherAG's own Package.swift/source untouched.

Usage:
  python3 resolve_warnings.py --diagnose  [--log /tmp/aetherag_build.log]
  python3 resolve_warnings.py --resolve   [--log /tmp/aetherag_build.log] [--dry-run]
  python3 resolve_warnings.py --rebuild-verify
"""
import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

MONO_ROOT = Path("/Users/nicreich/AetherAG-mono")
DEFAULT_LOG = Path("/tmp/aetherag_build.log")

WARNING_RE = re.compile(r"^(?P<file>/Users/[^:]+):(?P<line>\d+):(?P<col>\d+): warning: (?P<msg>.*)$")

# Map of vendored package roots we are allowed to patch (never AetherAG itself)
VENDOR_PACKAGES = {
    "solana-swift-patched": MONO_ROOT / "solana-swift-patched",
    "web3swift-patched": MONO_ROOT / "web3swift-patched",
}


def parse_log(log_path: Path):
    if not log_path.exists():
        print(f"ERROR: build log not found at {log_path}", file=sys.stderr)
        print(f"Run:  swift build 2>&1 | tee {log_path}", file=sys.stderr)
        sys.exit(1)

    text = log_path.read_text(errors="replace")
    warnings = []
    for line in text.splitlines():
        m = WARNING_RE.match(line)
        if m:
            warnings.append(m.groupdict())
    return warnings


def package_of(file_path: str) -> str:
    for pkg in VENDOR_PACKAGES:
        if f"/AetherAG-mono/{pkg}/" in file_path:
            return pkg
    if "/AetherAG-mono/AetherAG/" in file_path:
        return "AetherAG (own code)"
    if "/AetherAG-mono/AetherShared/" in file_path:
        return "AetherShared (own code)"
    if "/AetherAG-mono/AGWallet/" in file_path:
        return "AGWallet (own code)"
    return "other/unknown"


def diagnose(log_path: Path):
    warnings = parse_log(log_path)
    if not warnings:
        print("No compiler warnings found in log. Nothing to resolve.")
        return warnings

    by_pkg = defaultdict(list)
    for w in warnings:
        by_pkg[package_of(w["file"])].append(w)

    print(f"Total warnings: {len(warnings)}\n")
    print("=== By package ===")
    for pkg, ws in sorted(by_pkg.items(), key=lambda kv: -len(kv[1])):
        print(f"  {pkg:35s} {len(ws)} warning(s)")

    print("\n=== Own-code warnings (require manual review) ===")
    own_code = [w for pkg, ws in by_pkg.items() if "own code" in pkg for w in ws]
    if own_code:
        for w in own_code:
            print(f"  {w['file']}:{w['line']}:{w['col']}  {w['msg']}")
    else:
        print("  (none — all warnings are from vendored third-party packages)")

    print("\n=== Vendored-package warnings (safe to suppress at target level) ===")
    for pkg in VENDOR_PACKAGES:
        ws = by_pkg.get(pkg, [])
        if ws:
            print(f"  {pkg}: {len(ws)} warning(s)")
            for w in ws:
                rel = w["file"].split(f"{pkg}/", 1)[-1]
                print(f"    - {rel}:{w['line']}  {w['msg'][:80]}")
    return warnings


def find_target_name(pkg_root: Path, source_file: str) -> str | None:
    """Infer the SPM target name from a source file path (Sources/<Target>/...)."""
    try:
        rel = Path(source_file).relative_to(pkg_root)
    except ValueError:
        return None
    parts = rel.parts
    if len(parts) >= 2 and parts[0] == "Sources":
        return parts[1]
    return None


def patch_package_swift(pkg_root: Path, target_names: set[str], dry_run: bool):
    pkg_swift = pkg_root / "Package.swift"
    if not pkg_swift.exists():
        print(f"  SKIP: {pkg_swift} not found")
        return False

    original = pkg_swift.read_text()
    text = original
    changed = False

    for target in sorted(target_names):
        # Match a .target(name: "X", ... ) block for this target.
        pattern = re.compile(
            r'(\.target\(\s*name:\s*"' + re.escape(target) + r'"[^)]*?)(\))',
            re.DOTALL,
        )

        def add_swift_settings(m: re.Match) -> str:
            body, close = m.group(1), m.group(2)
            if "swiftSettings" in body:
                return m.group(0)  # already has settings; leave as-is
            insertion = (
                ',\n            swiftSettings: [\n'
                '                .unsafeFlags(["-suppress-warnings"])\n'
                '            ]'
            )
            return body + insertion + close

        new_text, n = pattern.subn(add_swift_settings, text)
        if n > 0:
            text = new_text
            changed = True
            print(f"  + suppress-warnings added to target '{target}' in {pkg_swift.name}")
        else:
            print(f"  ! could not locate .target(name: \"{target}\") in {pkg_swift.name} (skipped)")

    if changed and not dry_run:
        backup = pkg_swift.with_suffix(".swift.bak")
        backup.write_text(original)
        pkg_swift.write_text(text)
        print(f"  Backup saved to {backup}")
    elif changed and dry_run:
        print("  (dry-run: no files written)")

    return changed


def resolve(log_path: Path, dry_run: bool):
    warnings = diagnose(log_path)
    if not warnings:
        return

    own_code = [w for w in warnings if "own code" in package_of(w["file"])]
    if own_code:
        print(
            "\nWARNING: some warnings are in AetherAG's own source and will NOT be "
            "auto-suppressed. Review these manually:"
        )
        for w in own_code:
            print(f"  {w['file']}:{w['line']}  {w['msg']}")

    print("\n=== Patching vendored packages ===")
    for pkg_name, pkg_root in VENDOR_PACKAGES.items():
        targets = set()
        for w in warnings:
            if f"/AetherAG-mono/{pkg_name}/" in w["file"]:
                t = find_target_name(pkg_root, w["file"])
                if t:
                    targets.add(t)
        if not targets:
            continue
        print(f"\n{pkg_name} — targets to patch: {sorted(targets)}")
        patch_package_swift(pkg_root, targets, dry_run)

    if dry_run:
        print("\nDry run complete. Re-run without --dry-run to apply changes.")
    else:
        print(
            "\nDone. Re-run your build to verify warnings are gone:\n"
            "  cd ~/AetherAG-mono/AetherAG && swift build 2>&1 | tee /tmp/aetherag_build.log\n"
            "  bash /tmp/diagnose_warnings.sh"
        )


def rebuild_verify():
    print("Rebuilding AetherAG to verify warnings are resolved...")
    log = Path("/tmp/aetherag_build_verify.log")
    proc = subprocess.run(
        ["swift", "build"],
        cwd=str(MONO_ROOT / "AetherAG"),
        stdout=open(log, "w"),
        stderr=subprocess.STDOUT,
    )
    remaining = parse_log(log)
    print(f"Build exit code: {proc.returncode}")
    print(f"Remaining warnings: {len(remaining)}")
    if remaining:
        for w in remaining:
            print(f"  {w['file']}:{w['line']}  {w['msg']}")
    else:
        print("All warnings resolved.")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", type=Path, default=DEFAULT_LOG)
    ap.add_argument("--diagnose", action="store_true")
    ap.add_argument("--resolve", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--rebuild-verify", action="store_true")
    args = ap.parse_args()

    if args.rebuild_verify:
        rebuild_verify()
    elif args.resolve:
        resolve(args.log, args.dry_run)
    else:
        diagnose(args.log)


if __name__ == "__main__":
    main()
