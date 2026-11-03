#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
blockers: list[str] = []
warnings: list[str] = []

def run(*args: str) -> str:
    completed = subprocess.run(
        args,
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        blockers.append(
            f"Command failed ({' '.join(args)}): {completed.stderr.strip()}"
        )
    return completed.stdout

if run("git", "status", "--porcelain=v1").strip():
    warnings.append("Working tree is not clean; do not cut a release from this checkout.")

if run("git", "diff", "--check").strip():
    blockers.append("Working tree has whitespace errors.")

for line in run("git", "submodule", "status", "--recursive").splitlines():
    if line[:1] in {"+", "-", "U"}:
        blockers.append(f"Submodule state requires attention: {line}")

def search_tracked(*args: str) -> str:
    completed = subprocess.run(
        args, cwd=root, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if completed.returncode not in (0, 1):
        blockers.append(
            f"Tracked credential search failed (exit {completed.returncode})."
        )
        return ""
    return completed.stdout


def approved_workflow_template(line: str) -> bool:
    parts = line.split(":", 3)
    return (
        len(parts) == 4
        and parts[0] == "HEAD"
        and parts[1] == ".github/workflows/mailserver-docker.yml"
        and parts[2].isdigit()
        and parts[3].strip()
        == (
            'database_url="postgresql://'
            'postgres:${postgres_password}@${postgres}:5432/aetherag"'
        )
    )


tracked_matches = search_tracked(
    "git", "grep", "--no-color", "-nI", "-E",
    r"(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|"
    r"AKIA[0-9A-Z]{16}|"
    r"postgres(ql)?://[^[:space:]]+:[^[:space:]@]+@|"
    r"JWT_SECRET[[:space:]]*=[^[:space:]]+)",
    "HEAD", "--", ":(exclude)*.lock",
)
if tracked_matches.strip():
    approved_locations = {
        ".github/workflows/swift-ci.yml",
        "scripts/container-dev.sh",
        "scripts/start-rate-limit-server.sh",
    }
    secret_report = root / ".artifacts" / "tracked-secret-patterns-redacted.txt"
    secret_report.parent.mkdir(parents=True, exist_ok=True)
    locations = []
    for match in tracked_matches.splitlines():
        parts = match.split(":", 3)
        if len(parts) != 4 or parts[0] != "HEAD" or not parts[2].isdigit():
            blockers.append("Unexpected credential-search output format.")
            continue
        locations.append(f"{parts[1]}:{parts[2]}: credential-pattern match")
    secret_report.write_text(
        "\n".join(locations) + ("\n" if locations else ""),
        encoding="utf-8",
    )

    unexpected_matches = [
        line for line in tracked_matches.splitlines()
        if line.split(":", 2)[1] not in approved_locations
        and not approved_workflow_template(line)
    ]

    if unexpected_matches:
        blockers.append(
            "Potential credential material matched outside approved local/CI placeholders; "
            "inspect .artifacts/tracked-secret-patterns-redacted.txt."
        )
    else:
        warnings.append(
            "Tracked local/CI database placeholders matched the secret heuristic; "
            "reviewed allowlist only."
        )

if not tracked_matches.strip():
    secret_report = root / ".artifacts" / "tracked-secret-patterns-redacted.txt"
    secret_report.parent.mkdir(parents=True, exist_ok=True)
    secret_report.write_text("", encoding="utf-8")

print("Production baseline audit")
print(f"Repository: {root}")
print(f"Blockers: {len(blockers)}")
print(f"Warnings: {len(warnings)}")

for item in blockers:
    print(f"BLOCKER: {item}")

for item in warnings:
    print(f"WARNING: {item}")

sys.exit(1 if blockers else 0)
