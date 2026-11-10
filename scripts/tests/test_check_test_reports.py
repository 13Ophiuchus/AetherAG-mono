import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_test_reports.py"


class CheckTestReportsTests(unittest.TestCase):
    def run_reports(self, files, groups=("suite:report*.xml",)):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for name, content in files.items():
                (directory / name).write_text(content, encoding="utf-8")
            environment = os.environ.copy()
            environment.pop("GITHUB_STEP_SUMMARY", None)
            command = [
                sys.executable, str(SCRIPT),
                "--directory", str(directory),
            ]
            for group in groups:
                command += ["--group", group]
            return subprocess.run(
                command, env=environment, text=True, capture_output=True
            )

    def test_empty_companion_with_executed_swift_testing_passes(self):
        result = self.run_reports({
            "report.xml": '<testsuites tests="0"/>',
            "report-swift-testing.xml":
                '<testsuite><testcase name="ok"/></testsuite>',
        })
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_reports_fail(self):
        self.assertNotEqual(self.run_reports({}).returncode, 0)

    def test_malformed_report_fails_even_with_valid_companion(self):
        result = self.run_reports({
            "report.xml": "<broken",
            "report-swift-testing.xml":
                '<testsuite><testcase name="ok"/></testsuite>',
        })
        self.assertNotEqual(result.returncode, 0)

    def test_failure_and_error_elements_fail(self):
        for kind in ("failure", "error"):
            with self.subTest(kind=kind):
                result = self.run_reports({
                    "report.xml":
                        f'<testsuite><testcase><{kind}/></testcase></testsuite>'
                })
                self.assertNotEqual(result.returncode, 0)

    def test_failure_attribute_without_failure_element_fails(self):
        result = self.run_reports({
            "report.xml":
                '<testsuite failures="1"><testcase name="x"/></testsuite>'
        })
        self.assertNotEqual(result.returncode, 0)

    def test_all_skipped_group_fails(self):
        result = self.run_reports({
            "report.xml":
                '<testsuite><testcase><skipped/></testcase></testsuite>'
        })
        self.assertNotEqual(result.returncode, 0)

    def test_each_required_group_needs_executed_cases(self):
        result = self.run_reports(
            {"shared.xml": '<testsuite><testcase/></testsuite>'},
            ("shared:shared*.xml", "server:server*.xml"),
        )
        self.assertNotEqual(result.returncode, 0)

    def test_invalid_failure_count_fails(self):
        for value in ("invalid", "-1"):
            with self.subTest(value=value):
                result = self.run_reports({
                    "report.xml":
                        f'<testsuite failures="{value}"><testcase/></testsuite>'
                })
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
