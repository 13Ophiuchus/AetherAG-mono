#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", ".build", "DerivedData", "node_modules", ".swiftpm", "Pods"}
MODULES = {
    "root": ROOT,
    "AGWallet": ROOT / "AGWallet",
    "AetherAG": ROOT / "AetherAG",
    "AetherShared": ROOT / "AetherShared",
    "flow-swift-macos": ROOT / "flow-swift-macos",
    "solana-swift-concurrency": ROOT / "solana-swift-concurrency",
    "web3swift-concurrency": ROOT / "web3swift-concurrency",
}
TASK_PATTERN = re.compile(
    r"<!-- MILESTONE: (?P<id>[A-Z0-9-]+) \| module: (?P<module>[^|]+) "
    r"\| status: (?P<status>[^|]+) \| priority: (?P<priority>[^ ]+) -->"
)

def run(command: list[str], cwd: Path = ROOT, timeout: int = 45) -> dict:
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return {
            "command": " ".join(command),
            "exit_code": completed.returncode,
            "output": completed.stdout[-12000:],
        }
    except FileNotFoundError:
        return {"command": " ".join(command), "exit_code": 127, "output": "command not found"}
    except subprocess.TimeoutExpired as error:
        return {
            "command": " ".join(command),
            "exit_code": 124,
            "output": (error.stdout or "")[-12000:] + "\nTIMEOUT",
        }

def iter_source_files(path: Path):
    if not path.exists():
        return
    for current, directories, files in os.walk(path):
        directories[:] = [name for name in directories if name not in SKIP_DIRS]
        for filename in files:
            if filename.endswith((".swift", ".cadence", ".py", ".sh", ".yml", ".yaml")):
                yield Path(current) / filename

def count_files(path: Path, suffix: str) -> int:
    return sum(1 for file in iter_source_files(path) if file.suffix == suffix)

def search_count(path: Path, pattern: str) -> int:
    regex = re.compile(pattern, re.IGNORECASE)
    total = 0
    for file in iter_source_files(path):
        try:
            total += len(regex.findall(file.read_text(encoding="utf-8", errors="ignore")))
        except OSError:
            pass
    return total

def milestone_summary() -> dict:
    master = ROOT / "MASTER_MILESTONE.md"
    if not master.exists():
        return {"error": "MASTER_MILESTONE.md missing"}
    tasks = [match.groupdict() for match in TASK_PATTERN.finditer(master.read_text(encoding="utf-8"))]
    status = Counter(task["status"].strip() for task in tasks)
    module = Counter(task["module"].strip() for task in tasks)
    return {
        "task_count": len(tasks),
        "by_status": dict(sorted(status.items())),
        "by_module": dict(sorted(module.items())),
        "tasks": tasks,
    }

def module_state(name: str, path: Path) -> dict:
    result = {
        "name": name,
        "path": str(path.relative_to(ROOT)) if path != ROOT else ".",
        "exists": path.exists(),
    }
    if not path.exists():
        return result

    if (path / ".git").exists() or path == ROOT:
        result["git_status"] = run(["git", "status", "--short"], path)
        result["git_head"] = run(["git", "rev-parse", "--short", "HEAD"], path)
        result["git_branch"] = run(["git", "branch", "--show-current"], path)

    result["swift_files"] = count_files(path, ".swift")
    result["cadence_files"] = count_files(path, ".cadence")
    result["test_files"] = sum(
        1
        for file in iter_source_files(path)
        if "Test" in file.name or "Tests" in file.parts
    )
    result["package_swift"] = (path / "Package.swift").exists()
    result["xcode_projects"] = len(list(path.glob("*.xcodeproj")))
    result["xcode_workspaces"] = len(list(path.glob("*.xcworkspace")))
    result["security_markers"] = {
        "rate_limit": search_count(path, r"ratelimit|rate_limit|throttle"),
        "structured_logging": search_count(path, r"Logger\(|logger\.|log\."),
        "oid4vci": search_count(path, r"OID4VCI|oid4vci"),
        "oid4vp": search_count(path, r"OID4VP|vp_token|presentation_definition"),
        "revocation": search_count(path, r"credentialStatus|revokedAt|revocation"),
        "spl_token": search_count(path, r"SPL|Token Program|associated token"),
    }
    return result

def git_root_state() -> dict:
    return {
        "root": str(ROOT),
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "git_status": run(["git", "status", "--short"]),
        "git_diff_stat": run(["git", "diff", "--stat"]),
        "git_submodules": run(["git", "submodule", "status", "--recursive"]),
        "toolchain": {
            "python": run([sys.executable, "--version"]),
            "swift": run(["swift", "--version"]) if shutil.which("swift") else {"output": "swift unavailable"},
            "git": run(["git", "--version"]),
        },
    }

def render_markdown(data: dict) -> str:
    lines = [
        "# AetherAG Monorepo Discovery Report",
        "",
        f"Generated: `{data['repository']['timestamp_utc']}`",
        "",
        "## Repository",
        "",
        "```text",
        data["repository"]["git_status"]["output"].strip() or "working tree clean",
        "```",
        "",
        "## Milestones",
        "",
    ]
    milestones = data["milestones"]
    if "error" in milestones:
        lines.append(f"**Error:** {milestones['error']}")
    else:
        lines.append(f"- Total tracked tasks: {milestones['task_count']}")
        for status, count in milestones["by_status"].items():
            lines.append(f"- {status}: {count}")
        lines.append("")
        lines.append("| Module | Tasks |")
        lines.append("|---|---:|")
        for module, count in milestones["by_module"].items():
            lines.append(f"| {module} | {count} |")
    lines.extend(["", "## Modules", ""])
    for module in data["modules"]:
        lines.append(f"### {module['name']}")
        lines.append("")
        lines.append(f"- Path: `{module['path']}`")
        lines.append(f"- Exists: `{module['exists']}`")
        if module["exists"]:
            lines.append(
                f"- Swift files: {module['swift_files']}; Cadence files: {module['cadence_files']}; test files: {module['test_files']}"
            )
            lines.append(
                f"- Package.swift: `{module['package_swift']}`; Xcode projects: {module['xcode_projects']}; workspaces: {module['xcode_workspaces']}"
            )
            markers = module["security_markers"]
            lines.append(
                "- Signals: "
                + ", ".join(f"{key}={value}" for key, value in markers.items())
            )
            if "git_head" in module:
                lines.append(f"- HEAD: `{module['git_head']['output'].strip()}`")
                lines.append(f"- Branch: `{module['git_branch']['output'].strip()}`")
                status = module["git_status"]["output"].strip() or "working tree clean"
                lines.extend(["- Git status:", "```text", status, "```"])
        lines.append("")
    lines.extend(
        [
            "## Follow-up Commands",
            "",
            "```bash",
            "python3 scripts/sync_milestones.py --check",
            "python3 scripts/complete_milestone.py <TASK-ID> --evidence \"<validated command/result>\"",
            "```",
            "",
        ]
    )
    return "\n".join(lines)

def main() -> int:
    data = {
        "repository": git_root_state(),
        "milestones": milestone_summary(),
        "modules": [module_state(name, path) for name, path in MODULES.items()],
    }
    output_json = ROOT / "reports" / "current-state.json"
    output_md = ROOT / "reports" / "current-state.md"
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    output_md.write_text(render_markdown(data), encoding="utf-8")
    print(f"Wrote {output_md.relative_to(ROOT)}")
    print(f"Wrote {output_json.relative_to(ROOT)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
