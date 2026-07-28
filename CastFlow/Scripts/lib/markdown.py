#!/usr/bin/env python3

import re
from pathlib import Path


HEADER_PATTERN = re.compile(r"^#+\s", re.MULTILINE)

LINK_PATTERN = re.compile(
    r"\[([^\]]+)\]\(([^)]+)\)"
)

CODE_PATTERN = re.compile(
    r"```.*?```",
    re.DOTALL,
)


class MarkdownDocument:

    def __init__(self, path: Path):

        self.path = path

        self.text = path.read_text(
            encoding="utf-8",
            errors="ignore",
        )

    @property
    def headers(self):

        return HEADER_PATTERN.findall(self.text)

    @property
    def links(self):

        return LINK_PATTERN.findall(self.text)

    @property
    def code_blocks(self):

        return CODE_PATTERN.findall(self.text)

    def contains(self, phrase: str):

        return phrase.lower() in self.text.lower()
