#!/usr/bin/env python3
import argparse
import pathlib
import sys
from typing import List

SENTINEL_COMMENT = "// MARK: - Chain helpers"

SOLANA_HELPERS_SNIPPET = """
    // Returns the primary Solana address for the given chain configuration.
    func solanaAddress(for chain: ChainConfig) async throws -> String {
        // TODO: Derive Solana address from stored key material for the given chain.
        throw WalletError.unsupportedOperation("solanaAddress(for:) not yet implemented")
    }

    // Signs a Solana message for the given chain configuration.
    func signSolanaMessage(_ message: String, chain: ChainConfig) async throws -> String {
        // TODO: Implement real Solana message signing via stored key material.
        throw WalletError.unsupportedOperation("signSolanaMessage(_:chain:) not yet implemented")
    }

    // Signs a Solana transfer transaction for the given chain configuration.
    func signSolanaTransfer(_ transaction: SolanaTransaction, chain: ChainConfig) async throws -> String {
        // TODO: Implement real Solana transfer signing via stored key material.
        throw WalletError.unsupportedOperation("signSolanaTransfer(_:chain:) not yet implemented")
    }
"""

SOLANAMODULE_CALL_SNIPPET = """
    // Helper that delegates Solana message signing to KeyManagerActor.
    private func signMessageInternal(_ message: String, chain: ChainConfig) async throws -> String {
        try await keyManager.signSolanaMessage(message, chain: chain)
    }

    // Helper that delegates Solana transfer signing to KeyManagerActor.
    private func signTransferInternal(_ transaction: SolanaTransaction, chain: ChainConfig) async throws -> String {
        try await keyManager.signSolanaTransfer(transaction, chain: chain)
    }
"""

def read_lines(path: pathlib.Path):
    return path.read_text(encoding="utf-8").splitlines(keepends=True)

def write_lines(path: pathlib.Path, lines) -> None:
    path.write_text("".join(lines), encoding="utf-8")

def patch_keymanager(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    already_has_any = (
        "func solanaAddress(for chain: ChainConfig)" in content or
        "func signSolanaMessage(_ message: String, chain: ChainConfig)" in content or
        "func signSolanaTransfer(_ transaction: SolanaTransaction, chain: ChainConfig)" in content
    )
    if already_has_any:
        print("[patch_solana_helpers] KeyManager already contains one or more Solana helpers, no changes.")
        return

    try:
        sentinel_index = next(i for i, line in enumerate(lines) if SENTINEL_COMMENT in line)
    except StopIteration:
        print(
            f"[patch_solana_helpers] Sentinel comment '{SENTINEL_COMMENT}' not found in {path}. "
            f"Add it near your chain-specific helpers and rerun.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = SOLANA_HELPERS_SNIPPET.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    new_lines = (
        lines[: sentinel_index + 1]
        + ["\n"]
        + insertion_block
        + lines[sentinel_index + 1 :]
    )

    write_lines(path, new_lines)
    print(f"[patch_solana_helpers] Inserted Solana helpers into {path}.")

def patch_solanamodule(path: pathlib.Path) -> None:
    lines = read_lines(path)
    content = "".join(lines)

    has_message_helper = "signMessageInternal(_ message: String, chain: ChainConfig)" in content
    has_transfer_helper = "signTransferInternal(_ transaction: SolanaTransaction, chain: ChainConfig)" in content
    if has_message_helper and has_transfer_helper:
        print("[patch_solana_helpers] SolanaModule already has delegation helpers, no changes.")
        return

    try:
        last_brace_index = max(
            i for i, line in enumerate(lines) if line.strip().endswith("}")
        )
    except ValueError:
        print(
            f"[patch_solana_helpers] Could not find a closing brace in {path}; "
            f"manual inspection required.",
            file=sys.stderr,
        )
        sys.exit(1)

    insertion_block = SOLANAMODULE_CALL_SNIPPET.strip("\n").splitlines(keepends=True)
    insertion_block = [line + "\n" if not line.endswith("\n") else line for line in insertion_block]

    new_lines = (
        lines[: last_brace_index]
        + ["\n"]
        + insertion_block
        + lines[last_brace_index:]
    )

    write_lines(path, new_lines)
    print(f"[patch_solana_helpers] Inserted Solana delegation helpers into {path}.")

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch KeyManagerActor and SolanaModule with Solana helper wiring."
    )
    parser.add_argument(
        "--keymanager",
        type=pathlib.Path,
        required=True,
        help="Path to KeyManager.swift",
    )
    parser.add_argument(
        "--solanamodule",
        type=pathlib.Path,
        required=True,
        help="Path to SolanaModule.swift",
    )
    args = parser.parse_args()

    if not args.keymanager.exists():
        print(f"KeyManager.swift not found at {args.keymanager}", file=sys.stderr)
        sys.exit(1)

    if not args.solanamodule.exists():
        print(f"SolanaModule.swift not found at {args.solanamodule}", file=sys.stderr)
        sys.exit(1)

    patch_keymanager(args.keymanager)
    patch_solanamodule(args.solanamodule)

if __name__ == "__main__":
    main()
