import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2]


class CompleteMilestoneStatusTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        for name in ("complete_milestone.py", "sync_milestones.py"):
            shutil.copy2(
                SOURCE / "scripts" / name,
                self.root / "scripts" / name,
            )
        self.write_master()
        self.git("init", "-q")
        self.commit_fixture()

    def git(self, *args):
        return subprocess.run(
            ["git", *args],
            cwd=self.root,
            text=True,
            capture_output=True,
            check=True,
        )

    def commit_fixture(self):
        self.git("add", ".")
        self.git(
            "-c", "user.name=Milestone Test",
            "-c", "user.email=milestone-test@example.invalid",
            "-c", "core.hooksPath=/dev/null",
            "commit", "-qm", "Create isolated test fixture",
        )

    def write_master(self, marker="in_progress", visible="in_progress"):
        text = (
            "# Fixture\n\n"
            f"<!-- MILESTONE: GOV-001 | module: root | status: {marker}"
            " | priority: P0 -->\n"
            "#### GOV-001 — Fixture governance task\n\n"
            f"**Status:** {visible}\n"
            "**Priority:** P0\n"
            "**Dependencies:** None\n\n"
            "**Evidence:** Original evidence.\n"
        )
        (self.root / "MASTER_MILESTONE.md").write_text(text)

    def run_completion(self, task="GOV-001"):
        return subprocess.run(
            [
                sys.executable,
                "scripts/complete_milestone.py",
                task,
                "--evidence",
                r"Fixture validation; literal \1 remains literal.",
            ],
            cwd=self.root,
            text=True,
            capture_output=True,
        )

    def master(self):
        return (self.root / "MASTER_MILESTONE.md").read_text()

    def test_completion_updates_marker_visible_status_and_generated_view(self):
        result = self.run_completion()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("| status: done |", self.master())
        self.assertIn("**Status:** done", self.master())
        self.assertNotIn("**Status:** in_progress", self.master())
        self.assertIn(r"literal \1 remains literal", self.master())
        generated = (self.root / "MILESTONES.md").read_text()
        self.assertIn("- **Status:** `done`", generated)
        self.assertIn("**Status:** done", generated)
        check = subprocess.run(
            [sys.executable, "scripts/sync_milestones.py", "--check"],
            cwd=self.root,
            text=True,
            capture_output=True,
        )
        self.assertEqual(check.returncode, 0, check.stdout + check.stderr)

    def test_already_done_repairs_display_and_preserves_original_evidence(self):
        self.write_master(marker="done", visible="in_progress")
        self.commit_fixture()
        result = self.run_completion()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("**Status:** done", self.master())
        self.assertIn("**Evidence:** Original evidence.", self.master())
        self.assertNotIn("**Evidence:** Completed", self.master())

    def test_unknown_task_does_not_change_master(self):
        before = self.master()
        result = self.run_completion("UNKNOWN-999")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.master(), before)

    def test_dirty_checkout_is_rejected_without_modifying_master(self):
        (self.root / "unrelated.txt").write_text("Uncommitted fixture work\n")
        before = self.master()
        result = self.run_completion()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.master(), before)


if __name__ == "__main__":
    unittest.main()
