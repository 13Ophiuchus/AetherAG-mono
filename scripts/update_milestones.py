#!/usr/bin/env python3
"""Idempotently append dated milestone entries to canonical MILESTONES.md
files, and optionally merge+remove stray duplicate files.

Usage:
  python3 update_milestones.py --target aetherag --title "..." --body-file /tmp/note.md
  python3 update_milestones.py --target agwallet --title "..." --body-file /tmp/note.md
  python3 update_milestones.py --target migration --title "..." --body-file /tmp/note.md
  python3 update_milestones.py --cleanup-strays [--dry-run]
"""
import argparse
import hashlib
import pathlib
import sys

ROOT = pathlib.Path("/Users/nicreich/AetherAG-mono")

TARGETS = {
    "aetherag":  ROOT / "AetherAG" / "Public" / "MILESTONES.md",
    "agwallet":  ROOT / "AGWallet" / "Public" / "MILESTONES.md",
    "migration": ROOT / "MIGRATION_MILESTONES.md",
}

# Known stray/duplicate paths to reconcile against their canonical target.
STRAYS = {
    ROOT / "AetherAG" / "MILESTONES.md": TARGETS["aetherag"],
}


def marker_for(title: str) -> str:
    slug = hashlib.sha1(title.encode()).hexdigest()[:10]
    return f"<!-- milestone:update:{slug} -->"


def append_entry(path: pathlib.Path, title: str, body: str, dry_run: bool = False) -> bool:
    marker = marker_for(title)
    existing = path.read_text() if path.exists() else ""

    if marker in existing:
        print(f"[skip] {path} already contains entry for: {title}")
        return False

    entry = f"\n{marker}\n## {title}\n\n{body.strip()}\n"

    if dry_run:
        print(f"[dry-run] Would append to {path}:\n{entry}")
        return True

    with path.open("a") as f:
        f.write(entry)

    print(f"[ok] Appended to {path}: {title}")
    return True


def cleanup_strays(dry_run: bool = False) -> None:
    for stray_path, canonical_path in STRAYS.items():
        if not stray_path.exists():
            print(f"[skip] No stray file at {stray_path}")
            continue

        stray_content = stray_path.read_text().strip()
        if not stray_content:
            print(f"[skip] Stray file {stray_path} is empty")
            continue

        canonical_content = canonical_path.read_text() if canonical_path.exists() else ""

        if stray_content in canonical_content:
            print(f"[info] Content already present in {canonical_path}")
        else:
            if dry_run:
                print(f"[dry-run] Would append stray content from {stray_path} into {canonical_path}")
            else:
                with canonical_path.open("a") as f:
                    f.write(f"\n{stray_content}\n")
                print(f"[ok] Merged {stray_path} content into {canonical_path}")

        if dry_run:
            print(f"[dry-run] Would delete stray file {stray_path}")
        else:
            stray_path.unlink()
            print(f"[ok] Deleted stray file {stray_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=TARGETS.keys())
    parser.add_argument("--title")
    parser.add_argument("--body-file")
    parser.add_argument("--cleanup-strays", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.cleanup_strays:
        cleanup_strays(dry_run=args.dry_run)
        return 0

    if not (args.target and args.title and args.body_file):
        parser.error("--target, --title, and --body-file are required unless --cleanup-strays is set")

    path = TARGETS[args.target]
    body = pathlib.Path(args.body_file).read_text()
    append_entry(path, args.title, body, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
