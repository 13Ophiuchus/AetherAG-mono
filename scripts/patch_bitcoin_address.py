#!/usr/bin/env python3
import argparse
import pathlib
import sys
from typing import List


SENTINEL_COMMENT = "// MARK: - Chain helpers"


BITCOIN_HELPER_SNIPPET = """
    // Returns the primary Bitcoin address for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 key derivation and HD path strategy are finalized.
    public func bitcoinAddress(for chain: ChainConfig) async throws -> String {
        // TODO: Derive Bitcoin address from stored key material for the given chain.
        // For now, this is a placeholder that throws until the derivation is wired.
        throw WalletError.unsupportedOperation("bitcoinAddress(for:) not yet implemented")
    }
"""


BITCOINMODULE_CALL_SNIPPET = """
    // Helper that delegates address derivation to KeyManagerActor.
    private func getAddress(for chain: ChainConfig) async throws -> String {
        try await keyManager.bitcoinAddress(for: chain)
    }
"""


def read_lines(path: pathlib.Path) -> List[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def write_lines(path: pathlib.Path, lines: List[str]) -> None:
    path.write_text("".join(lines), encoding="utf-8")


def patch_keymanager(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    if "bitcoinAddress(for" in content:
        print(f"[patch_bitcoin_address] KeyManager already contains bitcoinAddress(for:), no changes.")
        return

    try:
        sentinel_index = next(
            i for i, line in enumerate(lines) if SENTINEL_COMMENT in line
        )
    except StopIteration:
        print(
            f"[patch_bitcoin_address] Sentinel comment '{SENTINEL_COMMENT}' not found in {path}. "
            f"Add it near your chain-specific helpers and rerun.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = BITCOIN_HELPER_SNIPPET.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    # Insert helper immediately after the sentinel comment
    new_lines = (
        lines[: sentinel_index + 1]
        + ["\n"]  # blank line for readability
        + insertion_block
        + lines[sentinel_index + 1 :]
    )

    write_lines(path, new_lines)
    print(f"[patch_bitcoin_address] Inserted bitcoinAddress(for:) into {path}.")


def patch_bitcoinmodule(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    if "getAddress(for chain: ChainConfig)" in content or "bitcoinAddress(for" in content:
        print(f"[patch_bitcoin_address] BitcoinModule already delegates to KeyManagerActor, no changes.")
        return

    # Simple strategy: append the helper near the bottom, before the final closing brace.
    try:
        last_brace_index = max(
            i for i, line in enumerate(lines) if line.strip().endswith("}")
        )
    except ValueError:
        print(
            f"[patch_bitcoin_address] Could not find a closing brace in {path}; "
            f"manual inspection required.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = BITCOINMODULE_CALL_SNIPPET.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    new_lines = (
        lines[: last_brace_index]
        + ["\n"]  # blank line for readability
        + insertion_block
        + lines[last_brace_index:]
    )

    write_lines(path, new_lines)
    print(f"[patch_bitcoin_address] Inserted getAddress(for:) into {path}.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch KeyManagerActor and BitcoinModule with bitcoinAddress(for:) wiring."
    )
    parser.add_argument(
        "--keymanager",
        type=pathlib.Path,
        required=True,
        help="Path to KeyManager.swift",
    )
    parser.add_argument(
        "--bitcoinmodule",
        type=pathlib.Path,
        required=True,
        help="Path to BitcoinModule.swift",
    )
    args = parser.parse_args()

    if not args.keymanager.exists():
        print(f"KeyManager.swift not found at {args.keymanager}", file=sys.stderr)
        sys.exit(1)

    if not args.bitcoinmodule.exists():
        print(f"BitcoinModule.swift not found at {args.bitcoinmodule}", file=sys.stderr)
        sys.exit(1)

    patch_keymanager(args.keymanager)
    patch_bitcoinmodule(args.bitcoinmodule)


if __name__ == "__main__":
    main()
