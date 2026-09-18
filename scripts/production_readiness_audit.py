#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "AetherAG" / "Sources" / "AetherAGMailServer"
TESTS = ROOT / "AetherAG" / "Tests"

def files_under(*roots: Path) -> list[Path]:
    result: list[Path] = []
    for root in roots:
        if root.exists():
            result.extend(path for path in root.rglob("*.swift") if path.is_file())
    return sorted(result)

def matches(pattern: str, roots: list[Path], flags: int = re.IGNORECASE) -> list[dict]:
    rx = re.compile(pattern, flags)
    findings: list[dict] = []
    for path in files_under(*roots):
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if rx.search(line):
                findings.append({
                    "path": str(path.relative_to(ROOT)),
                    "line": line_number,
                    "text": line.strip()[:300],
                })
    return findings

def git_diff_check() -> dict:
    completed = subprocess.run(
        ["git", "diff", "--check"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "exit_code": completed.returncode,
        "output": (completed.stdout + completed.stderr).strip(),
    }

scheduler_todos = matches(r"\bTODO\b", [SERVER / "Jobs"])
rate_limit_source = matches(r"OID4VCIRateLimitMiddleware|tooManyRequests|oid4vci:rl:", [SERVER])
rate_limit_tests = matches(r"RateLimit|tooManyRequests|429|oid4vci:rl:", [TESTS])
queue_tests = matches(r"PollFlowTransactionStatusJob|IssueCredentialJob|QueueSmokeTests", [TESTS])
sensitive_logs = matches(
    r"logger\.(info|notice|warning|error).*?(private.?key|mnemonic|seed|jwt.?secret|authorization|bearer|access.?token|pre-authorized)",
    [SERVER, ROOT / "AGWallet" / "Sources", ROOT / "AetherShared" / "Sources"],
)
git_check = git_diff_check()

status = {
    "git_diff_check": "pass" if git_check["exit_code"] == 0 else "fail",
    "flow_scheduler": "blocked" if scheduler_todos else "review",
    "rate_limit_tests": "missing" if not rate_limit_tests else "present",
    "queue_workflow_tests": "weak" if len(queue_tests) <= 2 else "present",
    "sensitive_log_findings": len(sensitive_logs),
}

report = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "status": status,
    "git_diff_check": git_check,
    "scheduler_todos": scheduler_todos,
    "rate_limit_source_matches": rate_limit_source,
    "rate_limit_test_matches": rate_limit_tests,
    "queue_test_matches": queue_tests,
    "sensitive_log_matches": sensitive_logs,
}

output_dir = ROOT / ".artifacts" / "reports"
output_dir.mkdir(parents=True, exist_ok=True)
json_path = output_dir / "production-readiness.json"
md_path = output_dir / "production-readiness.md"

json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

lines = [
    "# Production Readiness Audit",
    "",
    f"Generated: {report['generated_at']}",
    "",
    "## Status",
    "",
]
for key, value in status.items():
    lines.append(f"- `{key}`: **{value}**")

lines.extend([
    "",
    "## Required actions",
    "",
    "- Resolve `git diff --check` failures before release.",
    "- Implement the Flow scheduler database lookup and polling-job dispatch while preserving idempotency.",
    "- Add a Redis-backed rate-limit test that asserts HTTP 429 after the configured request threshold.",
    "- Add job tests for Flow sealed-success, sealed-failure, expired, retry, and issuance dispatch behavior.",
    "",
    "## Evidence",
    "",
    f"- Scheduler TODO findings: {len(scheduler_todos)}",
    f"- Rate-limit test findings: {len(rate_limit_tests)}",
    f"- Queue workflow test findings: {len(queue_tests)}",
    f"- Potential sensitive logging findings: {len(sensitive_logs)}",
])

md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(json_path)
print(md_path)
