#!/usr/bin/env python3

from dataclasses import dataclass, field


@dataclass
class Report:

    passed: list[str] = field(default_factory=list)

    warnings: list[str] = field(default_factory=list)

    failed: list[str] = field(default_factory=list)

    def ok(self, message):

        self.passed.append(message)

    def warn(self, message):

        self.warnings.append(message)

    def fail(self, message):

        self.failed.append(message)

    @property
    def success(self):

        return len(self.failed) == 0

    def print(self):

        print()

        print("========== REPORT ==========")

        for item in self.passed:

            print(f"✅ {item}")

        for item in self.warnings:

            print(f"⚠️  {item}")

        for item in self.failed:

            print(f"❌ {item}")

        print()

        print(
            f"Passed: {len(self.passed)}"
        )

        print(
            f"Warnings: {len(self.warnings)}"
        )

        print(
            f"Failed: {len(self.failed)}"
        )
