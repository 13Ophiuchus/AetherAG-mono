#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / ".production" / "milestone-state.json"

MILESTONES: list[dict[str, Any]] = [
    {
        "id": "AGW-LOG-001",
        "name": "Wallet logging redaction",
        "cwd": "AGWallet",
        "depends_on": [],
        "commands": [
            ["swift", "test"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "forbidden_regex",
                "paths": ["Sources/AetherWalletKit"],
                "pattern": r'logger\.(info|warning|error|debug)\([^\\n]*(message|recipientAddress|amount|txId|transactionId|result\.hash|signedPayload\.signature)',
                "description": "Wallet logs must not interpolate raw message, address, amount, transaction ID, hash, or signature values.",
            },
        ],
    },
    {
        "id": "AGW-SOL-002",
        "name": "Solana SPL production audit",
        "cwd": "AGWallet",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test", "--filter", "SolanaModuleTests"],
            ["swift", "test"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "docs/solana-spl-production-audit.md",
                "description": "SPL audit checklist must exist.",
            },
        ],
    },
    {
        "id": "AGW-EVM-003",
        "name": "EVM enrichment and indexer tests",
        "cwd": "AGWallet",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test", "--filter", "EVMModuleTests"],
            ["swift", "test"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "docs/evm-production-plan.md",
                "description": "EVM production plan must exist.",
            },
        ],
    },
    {
        "id": "AGW-CONFIG-004",
        "name": "Dynamic chain configuration coverage",
        "cwd": "AGWallet",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test", "--filter", "ChainConfigurationService"],
            ["swift", "test"],
            ["git", "diff", "--check"],
        ],
        "checks": [],
    },
    {
        "id": "AAG-REV-005",
        "name": "Credential-specific VP revocation",
        "cwd": "AetherAG",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test", "--filter", "CredentialStatusControllerTests"],
            ["swift", "test"],
            ["swift", "build", "-c", "release"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "docs/revocation-precision-plan.md",
                "description": "Revocation precision plan must exist.",
            },
        ],
    },
    {
        "id": "AAG-RATE-006",
        "name": "OID4VCI rate-limit verification",
        "cwd": "AetherAG",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test"],
            ["swift", "build", "-c", "release"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "Sources/AetherAGMailServer/Middleware/OID4VCIRateLimitMiddleware.swift",
                "description": "OID4VCI rate-limit middleware must exist.",
            },
            {
                "type": "required_file",
                "path": "docs/oid4vci-rate-limit-test-plan.md",
                "description": "Rate-limit test plan must exist.",
            },
        ],
    },
    {
        "id": "FLOW-RACE-007",
        "name": "Flow parallel test race removal",
        "cwd": "flow-swift-macos",
        "depends_on": ["AGW-LOG-001"],
        "commands": [
            ["swift", "test"],
            ["swift", "test"],
            ["swift", "test"],
            ["git", "diff", "--check"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "docs/test-race-validation.md",
                "description": "Flow race-validation plan must exist.",
            },
        ],
    },
    {
        "id": "REL-008",
        "name": "Production release gate",
        "cwd": ".",
        "depends_on": [
            "AGW-LOG-001",
            "AGW-SOL-002",
            "AGW-EVM-003",
            "AGW-CONFIG-004",
            "AAG-REV-005",
            "AAG-RATE-006",
            "FLOW-RACE-007",
        ],
        "commands": [
            ["git", "diff", "--check"],
            ["git", "status", "--short"],
        ],
        "checks": [
            {
                "type": "required_file",
                "path": "SECURITY.md",
                "description": "Responsible-disclosure policy must exist.",
            },
            {
                "type": "required_file",
                "path": "docs/production-release-gate.md",
                "description": "Production release gate must exist.",
            },
        ],
    },
]


def load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {"milestones": {}}
    try:
        return json.loads(STATE_PATH.read_text())
    except json.JSONDecodeError as error:
        raise SystemExit(f"Invalid state file {STATE_PATH}: {error}")


def save_state(state: dict[str, Any]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE_PATH.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    temporary.replace(STATE_PATH)


def milestone_by_id(identifier: str) -> dict[str, Any]:
    for milestone in MILESTONES:
        if milestone["id"] == identifier:
            return milestone
    raise SystemExit(f"Unknown milestone: {identifier}")


def command_display(command: list[str]) -> str:
    return " ".join(command)


def run_command(command: list[str], cwd: Path) -> bool:
    print(f"\n$ (cd {cwd} && {command_display(command)})", flush=True)
    result = subprocess.run(command, cwd=cwd, check=False)
    return result.returncode == 0


def source_files(root: Path, relative_paths: list[str]) -> list[Path]:
    result: list[Path] = []
    for relative_path in relative_paths:
        candidate = root / relative_path
        if candidate.is_file():
            result.append(candidate)
        elif candidate.is_dir():
            result.extend(candidate.rglob("*.swift"))
    return result


def run_check(check: dict[str, Any], cwd: Path) -> tuple[bool, str]:
    check_type = check["type"]

    if check_type == "required_file":
        path = cwd / check["path"]
        return path.is_file(), check["description"]

    if check_type == "forbidden_regex":
        import re

        expression = re.compile(check["pattern"])
        matches: list[str] = []
        for file_path in source_files(cwd, check["paths"]):
            text = file_path.read_text(errors="replace")
            for index, line in enumerate(text.splitlines(), start=1):
                if expression.search(line):
                    matches.append(f"{file_path.relative_to(cwd)}:{index}: {line.strip()}")

        if matches:
            print("\nForbidden log interpolation found:")
            for match in matches:
                print(f"  {match}")
        return not matches, check["description"]

    return False, f"Unsupported check type: {check_type}"


def dependencies_passed(milestone: dict[str, Any], state: dict[str, Any]) -> bool:
    statuses = state.get("milestones", {})
    missing = [
        dependency
        for dependency in milestone["depends_on"]
        if statuses.get(dependency, {}).get("status") != "passed"
    ]
    if missing:
        print(f"Blocked: unmet dependencies: {', '.join(missing)}")
        return False
    return True


def run_milestone(identifier: str) -> int:
    milestone = milestone_by_id(identifier)
    state = load_state()

    if not dependencies_passed(milestone, state):
        return 2

    cwd = (ROOT / milestone["cwd"]).resolve()
    if not cwd.is_dir():
        print(f"Missing working directory: {cwd}")
        return 2

    print(f"==> {milestone['id']}: {milestone['name']}")
    passed = True

    for command in milestone["commands"]:
        if not run_command(command, cwd):
            passed = False
            break

    if passed:
        for check in milestone["checks"]:
            check_passed, description = run_check(check, cwd)
            print(f"{'PASS' if check_passed else 'FAIL'}: {description}")
            if not check_passed:
                passed = False

    state.setdefault("milestones", {})[identifier] = {
        "name": milestone["name"],
        "status": "passed" if passed else "failed",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    save_state(state)

    print(f"\n{'PASSED' if passed else 'FAILED'}: {identifier}")
    return 0 if passed else 1


def print_status() -> None:
    state = load_state()
    statuses = state.get("milestones", {})

    for milestone in MILESTONES:
        entry = statuses.get(milestone["id"], {})
        status = entry.get("status", "pending")
        updated = entry.get("updated_at", "—")
        print(f"{milestone['id']:14} {status:8} {milestone['name']} ({updated})")


def main() -> int:
    parser = argparse.ArgumentParser(description="AetherAG production milestone runner")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list", help="List registered milestones")
    subparsers.add_parser("status", help="Show persisted milestone status")

    run_parser = subparsers.add_parser("run", help="Run a single milestone")
    run_parser.add_argument("milestone_id", choices=[m["id"] for m in MILESTONES])

    run_all_parser = subparsers.add_parser("run-all", help="Run milestones in dependency order")
    run_all_parser.add_argument(
        "--continue-on-failure",
        action="store_true",
        help="Continue after failures; blocked dependent milestones remain blocked.",
    )

    arguments = parser.parse_args()

    if arguments.command == "list":
        for milestone in MILESTONES:
            print(f"{milestone['id']:14} {milestone['name']}")
        return 0

    if arguments.command == "status":
        print_status()
        return 0

    if arguments.command == "run":
        return run_milestone(arguments.milestone_id)

    if arguments.command == "run-all":
        final_result = 0
        for milestone in MILESTONES:
            result = run_milestone(milestone["id"])
            if result != 0:
                final_result = result
                if not arguments.continue_on_failure:
                    return result
        return final_result

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
