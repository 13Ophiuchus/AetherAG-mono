"""Committed-fixture regression tests for the production baseline scanner."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class ProductionBaselineAuditTests(unittest.TestCase):
    def test_committed_fixtures(self):
        scanner = (ROOT / "scripts/production_baseline_audit.py").read_text()
        template = (
            'database_url="postgresql://'
            'postgres:${postgres_password}@${postgres}:5432/aetherag"\n'
        )
        literal = (
            'DATABASE_URL=postgresql://'
            'postgres:synthetic-test-only@db:5432/test\n'
        )
        modified = (
            'database_url="postgresql://'
            'postgres:synthetic-test-only@${postgres}:5432/aetherag"\n'
        )
        workflow = ".github/workflows/mailserver-docker.yml"
        cases = [
            ("clean", "README.md", "# Clean fixture\n", 0, None),
            ("approved-template", workflow, template, 0, "database_url="),
            ("literal-password", workflow, literal, 1, "synthetic-test-only"),
            ("modified-template", workflow, modified, 1, "synthetic-test-only"),
            ("wrong-path", "example.sh", template, 1, "database_url="),
            ("private-key-marker", workflow,
             "-----BEGIN " "PRIVATE KEY-----\n", 1, "BEGIN " "PRIVATE KEY"),
        ]

        for name, filename, fixture, expected, forbidden in cases:
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory(
                    prefix="aetherag-baseline-test-"
                ) as temporary:
                    root = Path(temporary)
                    script = root / "scripts/production_baseline_audit.py"
                    script.parent.mkdir(parents=True)
                    script.write_text(scanner)
                    test_source = Path(__file__).read_text()
                    test_copy = root / "scripts/tests/test_production_baseline_audit.py"
                    test_copy.parent.mkdir(parents=True, exist_ok=True)
                    test_copy.write_text(test_source)
                    target = root / filename
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(fixture)

                    def git(*args):
                        subprocess.run(
                            ["git", *args],
                            cwd=root,
                            check=True,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE,
                        )

                    git("init", "-q")
                    git("add", ".")
                    git(
                        "-c", "user.name=CI Fixture",
                        "-c", "user.email=fixture@example.invalid",
                        "-c", "core.hooksPath=/dev/null",
                        "commit", "-qm", "Synthetic fixture",
                    )

                    report_path = (
                        root / ".artifacts/tracked-secret-patterns-redacted.txt"
                    )
                    if name == "clean":
                        report_path.parent.mkdir(parents=True)
                        report_path.write_text("synthetic-stale-report\n")

                    result = subprocess.run(
                        [sys.executable, str(script)],
                        cwd=root,
                        text=True,
                        capture_output=True,
                    )
                    self.assertEqual(
                        result.returncode,
                        expected,
                        (result.stdout, result.stderr),
                    )

                    report = report_path.read_text()
                    if forbidden:
                        self.assertNotIn(forbidden, report)
                    if expected:
                        self.assertIn("credential-pattern match", report)
                    if name == "clean":
                        self.assertEqual(report, "")


if __name__ == "__main__":
    unittest.main()
