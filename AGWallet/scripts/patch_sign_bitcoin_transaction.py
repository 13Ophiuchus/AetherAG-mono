#!/usr/bin/env python3
import argparse
import pathlib
import sys
from typing import List

SENTINEL_COMMENT = "// MARK: - Chain helpers"

BITCOIN_SIGN_TX_HELPER = """
    // Signs a Bitcoin transaction draft for the given chain configuration.
    // This implementation is deliberately conservative; it should be refined
    // once secp256k1 transaction signing strategy is finalized.
    func signBitcoinTransaction(_ draft: BitcoinTxDraft, chain: ChainConfig) async throws -> String {
        // TODO: Implement real Bitcoin transaction signing via stored key material.
        throw WalletError.unsupportedOperation("signBitcoinTransaction(_:chain:) not yet implemented")
    }
"""

BITCOINMODULE_CALL_SNIPPET = """
    // Helper that delegates Bitcoin transaction signing to KeyManagerActor.
    private func signTransactionInternal(_ draft: BitcoinTxDraft, chain: ChainConfig) async throws -> String {
        try await keyManager.signBitcoinTransaction(draft, chain: chain)
    }
"""

def read_lines(path: pathlib.Path) -> List[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)

def write_lines(path: pathlib.Path, lines: List[str]) -> None:
    path.write_text("".join(lines), encoding="utf-8")

def patch_keymanager(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    if "func signBitcoinTransaction(_ draft: BitcoinTxDraft, chain: ChainConfig)" in content:
        print("[patch_sign_bitcoin_transaction] KeyManager already contains signBitcoinTransaction(_:chain:), no changes.")
        return

    try:
        sentinel_index = next(i for i, line in enumerate(lines) if SENTINEL_COMMENT in line)
    except StopIteration:
        print(
            f"[patch_sign_bitcoin_transaction] Sentinel comment '{SENTINEL_COMMENT}' not found in {path}. "
            f"Add it near your chain-specific helpers and rerun.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = BITCOIN_SIGN_TX_HELPER.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    new_lines = (
        lines[: sentinel_index + 1]
        + ["\n"]
        + insertion_block
        + lines[sentinel_index + 1 :]
    )

    write_lines(path, new_lines)
    print(f"[patch_sign_bitcoin_transaction] Inserted signBitcoinTransaction(_:chain:) into {path}.")

def patch_bitcoinmodule(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    if "signTransactionInternal(_ draft: BitcoinTxDraft, chain: ChainConfig)" in content:
        print("[patch_sign_bitcoin_transaction] BitcoinModule already has signTransactionInternal, no changes.")
        return

    try:
        last_brace_index = max(
            i for i, line in enumerate(lines) if line.strip().endswith("}")
        )
    except ValueError:
        print(
            f"[patch_sign_bitcoin_transaction] Could not find a closing brace in {path}; "
            f"manual inspection required.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = BITCOINMODULE_CALL_SNIPPET.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    new_lines = (
        lines[: last_brace_index]
        + ["\n"]
        + insertion_block
        + lines[last_brace_index:]
    )

    write_lines(path, new_lines)
    print(f"[patch_sign_bitcoin_transaction] Inserted signTransactionInternal(_:chain:) into {path}.")

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch KeyManagerActor and BitcoinModule with signBitcoinTransaction(_:chain:) wiring."
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
