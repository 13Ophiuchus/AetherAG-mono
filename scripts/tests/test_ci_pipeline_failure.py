import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/swift-ci.yml"


class CIPipelineFailureTests(unittest.TestCase):
    def step(self, identifier):
        text = WORKFLOW.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        positions = [
            index for index, line in enumerate(lines)
            if line.rstrip("\n") == f"        id: {identifier}"
        ]
        self.assertEqual(len(positions), 1, identifier)
        id_index = positions[0]

        step_start = next(
            (index for index in range(id_index - 1, -1, -1)
             if lines[index].startswith("      - ")),
            None,
        )
        self.assertIsNotNone(step_start, identifier)

        step_end = len(lines)
        for index in range(id_index + 1, len(lines)):
            line = lines[index]
            if not line.strip():
                continue
            indentation = len(line) - len(line.lstrip(" "))
            if indentation <= 6:
                step_end = index
                break

        run_positions = [
            index for index in range(id_index + 1, step_end)
            if lines[index].rstrip("\n") == "        run: |"
        ]
        self.assertEqual(len(run_positions), 1, identifier)
        run_index = run_positions[0]

        metadata = "".join(lines[step_start:run_index])
        self.assertIn("        shell: bash\n", metadata)

        body_lines = []
        for line in lines[run_index + 1:step_end]:
            if not line.strip():
                body_lines.append("\n")
            elif line.startswith("          "):
                body_lines.append(line[10:])
            else:
                break

        body = "".join(body_lines)
        self.assertTrue(body.strip(), identifier)
        self.assertIn("set -euo pipefail\n", body)
        self.assertIn(
            f"if: always() && steps.{identifier}.outcome == 'failure'",
            text,
        )
        return body

    def test_extractor_excludes_yaml_metadata(self):
        for identifier, count in (
            ("agwallet_test", 1),
            ("aether_linux_test", 3),
            ("aether_macos_test", 1),
        ):
            with self.subTest(step=identifier):
                body = self.step(identifier)
                self.assertEqual(
                    len(re.findall(r"^\s*swift test\b", body, re.MULTILINE)),
                    count,
                )
                self.assertNotIn("continue-on-error:", body)
                self.assertNotIn("      - name:", body)
                self.assertNotIn("uses: actions/", body)

    def run_fake_tests(self, body, fail_at):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            binaries = directory / "bin"
            binaries.mkdir()
            fake = binaries / "swift"
            fake.write_text(
                "#!/bin/bash\n"
                "set -eu\n"
                'count=0\n'
                'if [ -f "$COUNT_FILE" ]; then count=$(cat "$COUNT_FILE"); fi\n'
                'count=$((count + 1))\n'
                'printf "%s\\n" "$count" > "$COUNT_FILE"\n'
                'printf "fake swift invocation %s\\n" "$count"\n'
                'if [ "$FAIL_AT" -eq "$count" ]; then exit 7; fi\n'
                "exit 0\n"
            )
            fake.chmod(0o700)
            environment = os.environ.copy()
            environment.update({
                "PATH": str(binaries) + os.pathsep + environment["PATH"],
                "COUNT_FILE": str(directory / "count"),
                "FAIL_AT": str(fail_at),
            })
            return subprocess.run(
                ["/bin/bash", "-e", "-c", body],
                cwd=directory,
                env=environment,
                text=True,
                capture_output=True,
            )

    def check_step(self, identifier, invocations):
        body = self.step(identifier)
        self.assertEqual(
            len(re.findall(r"^\s*swift test\b", body, re.MULTILINE)),
            invocations,
        )
        for fail_at in range(1, invocations + 1):
            with self.subTest(step=identifier, fail_at=fail_at):
                result = self.run_fake_tests(body, fail_at)
                self.assertEqual(
                    result.returncode, 7,
                    result.stdout + result.stderr,
                )
        result = self.run_fake_tests(body, 0)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_agwallet_propagates_failure(self):
        self.check_step("agwallet_test", 1)

    def test_linux_propagates_each_suite_failure(self):
        self.check_step("aether_linux_test", 3)

    def test_macos_propagates_failure(self):
        self.check_step("aether_macos_test", 1)


if __name__ == "__main__":
    unittest.main()
