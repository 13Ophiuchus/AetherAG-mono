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
    if not args.evidence.strip() or any(c in args.evidence for c in "\r\n"):
        parser.error("--evidence must be nonempty, single-line reviewed evidence")

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

    updated = text[:match.start("status")] + "done" + text[match.end("status"):]
    section_pattern = re.compile(
        rf"(<!-- MILESTONE: {re.escape(args.task_id)} .*?-->.*?)(?=\n<!-- MILESTONE: |\n## |\n### |\Z)",
        re.DOTALL,
    )
    section = section_pattern.search(updated)
    if not section:
        print(f"Could not locate body for {args.task_id}.", file=sys.stderr)
        return 2

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    evidence_line = f"**Evidence:** Completed {timestamp}. {args.evidence}"
    section_text = section.group(1)
    visible_pattern = r"^\*\*Status:\*\* (not_started|in_progress|blocked|done)[ \t]*$"
    visible = re.findall(visible_pattern, section_text, re.MULTILINE)
    if visible != [match.group("status").strip()]:
        print("Task marker/body status mismatch; review an exact correction separately.", file=sys.stderr)
        return 2
    if match.group("status").strip() == "done":
        print(f"Task {args.task_id} is already consistently marked done.")
        return 0
    section_text = re.sub(
        visible_pattern, "**Status:** done", section_text, count=1, flags=re.MULTILINE
    )
    if "**Evidence:**" in section_text:
        section_text = re.sub(
            r"^\*\*Evidence:\*\*[^\r\n]*$",
            lambda _: evidence_line, section_text, flags=re.MULTILINE,
        )
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
