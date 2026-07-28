#!/usr/bin/env python3

"""
Detect circular Swift imports.
"""

from pathlib import Path
import re
import sys

IMPORT = re.compile(r"^\s*import\s+([A-Za-z0-9_]+)", re.MULTILINE)

graph = {}

for file in Path("Sources").rglob("*.swift"):

    parts = file.parts

    if "Sources" not in parts:
        continue

    module = parts[parts.index("Sources") + 1]

    graph.setdefault(module, set())

    imports = IMPORT.findall(
        file.read_text(
            encoding="utf8",
            errors="ignore"
        )
    )

    for imp in imports:

        graph[module].add(imp)


visited = set()
stack = []


def visit(node):

    if node in stack:

        cycle = stack + [node]

        print("Cycle detected")

        print(" -> ".join(cycle))

        sys.exit(1)

    if node in visited:
        return

    visited.add(node)

    stack.append(node)

    for nxt in graph.get(node, []):

        if nxt in graph:

            visit(nxt)

    stack.pop()


for node in graph:

    visit(node)

print("✓ No circular dependencies")
