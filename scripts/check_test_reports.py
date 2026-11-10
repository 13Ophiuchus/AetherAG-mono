#!/usr/bin/env python3
import argparse
import os
import xml.etree.ElementTree as ET
from pathlib import Path


def tag(element):
    return element.tag.rsplit("}", 1)[-1]


def inspect_group(directory, specification):
    name, separator, pattern = specification.partition(":")
    if not separator or not name or not pattern:
        raise ValueError("Groups must use NAME:GLOB syntax.")
    if "/" in pattern or "\\" in pattern or not pattern.endswith(".xml"):
        raise ValueError("Group patterns must select XML files in one directory.")

    counts = dict(reported=0, executed=0, skipped=0, failures=0, errors=0)
    problems = []
    files = sorted(path for path in directory.glob(pattern) if path.is_file())
    if not files:
        problems.append(f"{name}: no matching XML reports")

    for path in files:
        try:
            root = ET.parse(path).getroot()
        except (ET.ParseError, OSError):
            problems.append(f"{path.name}: unreadable or malformed XML")
            continue

        if tag(root) not in ("testsuite", "testsuites"):
            problems.append(f"{path.name}: unsupported XML root")
            continue

        elements = list(root.iter())
        cases = [element for element in elements if tag(element) == "testcase"]
        skipped = sum(
            any(tag(child) == "skipped" for child in case)
            for case in cases
        )
        counts["reported"] += len(cases)
        counts["executed"] += len(cases) - skipped
        counts["skipped"] += skipped
        counts["failures"] += sum(tag(element) == "failure" for element in elements)
        counts["errors"] += sum(tag(element) == "error" for element in elements)

        for element in elements:
            if tag(element) not in ("testsuite", "testsuites"):
                continue
            for attribute in ("failures", "errors"):
                raw = element.get(attribute)
                if raw is None:
                    continue
                try:
                    value = int(raw)
                    if value < 0:
                        raise ValueError
                except ValueError:
                    problems.append(f"{path.name}: invalid {attribute} attribute")
                    continue
                if value:
                    problems.append(f"{path.name}: reports {attribute}={value}")

    if counts["executed"] == 0:
        problems.append(f"{name}: no executed test cases")
    if counts["failures"] or counts["errors"]:
        problems.append(f"{name}: failure/error elements present")

    return name, counts, problems


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--group", required=True, action="append")
    parser.add_argument("--title", default="Test report validation")
    args = parser.parse_args()

    rows = []
    problems = []
    try:
        for specification in args.group:
            name, counts, errors = inspect_group(args.directory, specification)
            rows.append((name, counts))
            problems.extend(errors)
    except ValueError as error:
        parser.error(str(error))

    lines = [
        f"## {args.title}",
        "",
        "| Group | Reported | Executed | Skipped | Failure records | Error records |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, counts in rows:
        values = " | ".join(str(value) for value in counts.values())
        lines.append(f"| {name} | {values} |")
    lines += [
        "",
        "Executed excludes skipped cases; it does not mean passed.",
        "Counts include matching XCTest and Swift Testing reports.",
    ]
    if problems:
        lines += ["", "### Report problems"]
        lines.extend(f"- {problem}" for problem in problems)

    content = "\n".join(lines) + "\n"
    print(content, end="")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with Path(summary).open("a", encoding="utf-8") as stream:
            stream.write(content)

    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
