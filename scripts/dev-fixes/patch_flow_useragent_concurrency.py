#!/usr/bin/env python3
"""
Idempotent patch for the vendored 'Flow' SwiftPM checkout
(13Ophiuchus/flow-swift-macos), fixing a Swift 6 strict-concurrency error:

  error: main actor-isolated default value in a nonisolated context
      static let deviceVersion: String = {
          let currentDevice = UIDevice.current   // UIDevice.current is @MainActor

Fix: wrap the UIDevice.current access in MainActor.assumeIsolated {}.

IMPORTANT: there can be multiple 'flow-swift-macos' directories in this repo
(e.g. a stray manual clone at the repo root AND the real SwiftPM-managed
checkout under .build/.../SourcePackages/checkouts/). Only the SwiftPM
checkout under a 'SourcePackages/checkouts' path is actually used by
xcodebuild. This script patches ALL matching files it finds, and reports
each one explicitly so stray/irrelevant copies don't create false
confidence.

This script is safe to re-run: it checks for the already-patched marker
before editing, so it can be invoked on every build without double-patching
a fresh checkout re-fetched by SwiftPM.
"""
import sys
from pathlib import Path

MARKER = "// PATCHED: main-actor isolation fix for Swift 6 strict concurrency"

OLD_BLOCK = '''		/// eg. iOS/10.1 or macOS/14.2.1
	static let deviceVersion: String = {
#if os(iOS)
		let currentDevice = UIDevice.current
		let name = currentDevice.systemName.isEmpty ? "iOS" : currentDevice.systemName
		let version = currentDevice.systemVersion.isEmpty ? "0.0" : currentDevice.systemVersion
		return "\\(name)/\\(version)"
#elseif os(macOS)'''

NEW_BLOCK = f'''		/// eg. iOS/10.1 or macOS/14.2.1
	{MARKER}
	static let deviceVersion: String = {{
#if os(iOS)
		return MainActor.assumeIsolated {{
			let currentDevice = UIDevice.current
			let name = currentDevice.systemName.isEmpty ? "iOS" : currentDevice.systemName
			let version = currentDevice.systemVersion.isEmpty ? "0.0" : currentDevice.systemVersion
			return "\\(name)/\\(version)"
		}}
#elseif os(macOS)'''

CLOSE_OLD = '''		return "macOS/\\(major).\\(minor).\\(patch)"
#else
		return "unknownOS/0.0"
#endif
	}()'''

CLOSE_NEW = '''		return "macOS/\\(major).\\(minor).\\(patch)"
#else
		return "unknownOS/0.0"
#endif
	}()
	// END PATCHED BLOCK'''


def find_targets(repo_root: Path) -> list[Path]:
    return sorted(repo_root.glob("**/flow-swift-macos/Sources/Network/UserAgent.swift"))


def patch_one(target: Path) -> str:
    text = target.read_text()

    if MARKER in text:
        return f"OK (already patched): {target}"

    if OLD_BLOCK not in text or CLOSE_OLD not in text:
        return f"WARNING (source block not found, upstream may differ): {target}"

    patched = text.replace(OLD_BLOCK, NEW_BLOCK).replace(CLOSE_OLD, CLOSE_NEW)
    target.write_text(patched)
    return f"FIXED: {target}"


def main() -> int:
    repo_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    targets = find_targets(repo_root)

    if not targets:
        print("INFO: no UserAgent.swift checkout found yet (SwiftPM hasn't fetched it). Skipping patch.")
        return 0

    print(f"Found {len(targets)} matching file(s) under {repo_root}:")
    is_derived_data_patched = False
    relevant_warning = False
    for target in targets:
        result = patch_one(target)
        print(f"  - {result}")
        is_relevant = "SourcePackages/checkouts" in str(target)
        if is_relevant and ("FIXED" in result or "already patched" in result):
            is_derived_data_patched = True
        if "WARNING" in result and is_relevant:
            # Only a WARNING on a checkout that xcodebuild actually uses
            # (SourcePackages/checkouts) should be treated as fatal. Stray
            # manual clones or irrelevant module checkouts (e.g. a nested
            # server target's own .build dir) are informational only and
            # must never fail the overall build script.
            relevant_warning = True

    if not is_derived_data_patched:
        print("")
        print("WARNING: none of the patched files are under a 'SourcePackages/checkouts' path.")
        print("The actual DerivedData checkout used by xcodebuild may still be unpatched.")
        print("Run this AFTER 'xcodebuild -resolvePackageDependencies' or after the build's")
        print("dependency resolution step has created .build/DerivedData*/SourcePackages/checkouts/.")
        return 1

    if relevant_warning:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
