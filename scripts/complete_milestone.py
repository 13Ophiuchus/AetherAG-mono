#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "MASTER_MILESTONE.md"

def git_output(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Mark one master milestone task complete and regenerate derived module views."
    )
    parser.add_argument("task_id", help="Stable task ID, for example AAG-002")
    parser.add_argument(
        "--evidence",
        required=True,
        help="Concise validation evidence, for example: swift test --filter RevokedVPTests",
    )
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        help="Allow modifying a working tree that already has changes.",
    )
    args = parser.parse_args()

    if not MASTER.exists():
        print("MASTER_MILESTONE.md is missing.", file=sys.stderr)
        return 2

    if not args.allow_dirty and git_output("status", "--porcelain"):
        print(
            "Working tree is not clean. Commit/stash existing changes or use --allow-dirty deliberately.",
            file=sys.stderr,
        )
        return 2

    text = MASTER.read_text(encoding="utf-8")
    marker = re.compile(
        rf"(<!-- MILESTONE: {re.escape(args.task_id)} \| module: [^|]+ \| status: )"
        rf"(?P<status>[^|]+)( \| priority: [^ ]+ -->)"
    )
    match = marker.search(text)
    if not match:
        print(f"Task {args.task_id} was not found.", file=sys.stderr)
        return 2
    if match.group("status").strip() == "done":
        print(f"Task {args.task_id} is already marked done.")
        return 0

    updated = text[:match.start("status")] + "done" + text[match.end("status"):]
    section_pattern = re.compile(
        rf"(<!-- MILESTONE: {re.escape(args.task_id)} .*?-->.*?)(?=\n<!-- MILESTONE: |\Z)",
        re.DOTALL,
    )
    section = section_pattern.search(updated)
    if not section:
        print(f"Could not locate body for {args.task_id}.", file=sys.stderr)
        return 2

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    evidence_line = f"**Evidence:** Completed {timestamp}. {args.evidence}"
    section_text = section.group(1)
    if "**Evidence:**" in section_text:
        section_text = re.sub(r"\*\*Evidence:\*\*.*", evidence_line, section_text)
    else:
        section_text = section_text.rstrip() + "\n\n" + evidence_line
    updated = updated[:section.start(1)] + section_text + updated[section.end(1):]
    MASTER.write_text(updated, encoding="utf-8")

    subprocess.run(
        [sys.executable, "scripts/sync_milestones.py"],
        cwd=ROOT,
        check=True,
    )
    print(f"Marked {args.task_id} done and synchronized module milestone views.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
