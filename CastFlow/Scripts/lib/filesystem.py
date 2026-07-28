#!/usr/bin/env python3

from pathlib import Path


class Repository:

    def __init__(self, root: Path):

        self.root = root

    def markdown_files(self):

        return sorted(self.root.rglob("*.md"))

    def swift_files(self):

        return sorted(self.root.rglob("*.swift"))

    def python_files(self):

        return sorted(self.root.rglob("*.py"))

    def all_files(self):

        return sorted(self.root.rglob("*"))

    def exists(self, path: str):

        return (self.root / path).exists()

    def read(self, path: Path):

        return path.read_text(
            encoding="utf-8",
            errors="ignore",
        )
