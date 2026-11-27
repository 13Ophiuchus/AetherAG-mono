from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "sync_milestones.py"
SPEC = importlib.util.spec_from_file_location("sync_milestones_under_test", SCRIPT)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


def task(task_id="ZZZ-001", marker="in_progress", body="in_progress", heading=None):
    heading = heading if heading is not None else f"#### {task_id} \u2014 Example"
    return (
        f"<!-- MILESTONE: {task_id} | module: root | status: {marker} | priority: P0 -->\n"
        f"{heading}\n\n**Status:** {body}\n**Priority:** P0\n"
    )


class SyncMilestoneValidationTests(unittest.TestCase):
    def test_consistent_task_is_accepted(self):
        tasks = sync.parse_tasks(task())
        self.assertEqual([item["id"] for item in tasks], ["ZZZ-001"])

    def test_marker_and_body_status_mismatch_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "marker/body status mismatch"):
            sync.parse_tasks(task(marker="done", body="in_progress"))

    def test_missing_body_status_is_rejected(self):
        text = task().replace("**Status:** in_progress\n", "")
        with self.assertRaisesRegex(ValueError, "marker/body status mismatch"):
            sync.parse_tasks(text)

    def test_duplicate_body_status_is_rejected(self):
        text = task() + "**Status:** in_progress\n"
        with self.assertRaisesRegex(ValueError, "marker/body status mismatch"):
            sync.parse_tasks(text)

    def test_wrong_task_heading_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "expected a matching task heading"):
            sync.parse_tasks(task(heading="#### OTHER-001 \u2014 Example"))

    def test_malformed_marker_is_not_silently_skipped(self):
        bad = "<!-- MILESTONE: ZZZ-002 | module: root | status: done -->\n#### ZZZ-002 \u2014 X\n"
        with self.assertRaisesRegex(ValueError, "Malformed or unparsed milestone marker"):
            sync.parse_tasks(task() + "\n" + bad)


if __name__ == "__main__":
    unittest.main()
