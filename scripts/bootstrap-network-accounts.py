#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import getpass
import json
import os
import re
import secrets
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SECRETS_DIR = ROOT / ".secrets"
ENV_FILE = ROOT / ".env.development.local"
MANIFEST_FILE = SECRETS_DIR / "development-network-accounts.json"
GITIGNORE = ROOT / ".gitignore"

DEFAULTS = {
    "evm_testnet_rpc_url": "https://ethereum-sepolia-rpc.publicnode.com",
    "solana_testnet_rpc_url": "https://api.testnet.solana.com",
    "flow_testnet_access_node_url": "https://rest-testnet.onflow.org",
    "bitcoin_testnet_esplora_url": "https://blockstream.info/testnet/api",
    "bitcoin_signet_esplora_url": "https://mempool.space/signet/api",
}

def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)

def ensure_mode_600(path: Path) -> None:
    path.chmod(stat.S_IRUSR | stat.S_IWUSR)

def ensure_gitignore() -> None:
    entries = [
        ".env.development.local",
        ".secrets/",
        ".venv/",
    ]
    existing = GITIGNORE.read_text() if GITIGNORE.exists() else ""
    additions = [entry for entry in entries if re.search(rf"(?m)^{re.escape(entry)}$", existing) is None]
    if additions:
        with GITIGNORE.open("a", encoding="utf-8") as handle:
            if existing and not existing.endswith("\n"):
                handle.write("\n")
            handle.write("\n# Local development wallet material — never commit\n")
            handle.write("\n".join(additions))
            handle.write("\n")

def load_manifest() -> dict[str, Any]:
    if not MANIFEST_FILE.exists():
        return {
            "version": 1,
            "environment": "development",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "accounts": {},
        }
    ensure_mode_600(MANIFEST_FILE)
    try:
        return json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        die(f"cannot parse {MANIFEST_FILE}: {error}")

def save_manifest(manifest: dict[str, Any]) -> None:
    SECRETS_DIR.mkdir(mode=0o700, exist_ok=True)
    temp = MANIFEST_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    ensure_mode_600(temp)
    temp.replace(MANIFEST_FILE)
    ensure_mode_600(MANIFEST_FILE)

def require_package(name: str) -> None:
    try:
        __import__(name)
    except ImportError:
        die(
            f"missing Python package '{name}'. Run:\n"
            "  .venv/bin/python -m pip install --upgrade eth-account solders base58"
        )

def generate_evm_account() -> dict[str, str]:
    require_package("eth_account")
    from eth_account import Account
    account = Account.create(secrets.token_bytes(32))
    return {
        "address": account.address,
        "private_key_hex": account.key.hex(),
    }

def generate_solana_account() -> dict[str, str]:
    require_package("solders")
    from solders.keypair import Keypair
    keypair = Keypair()
    secret_bytes = bytes(keypair)
    return {
        "address": str(keypair.pubkey()),
        "secret_key_base64": base64.b64encode(secret_bytes).decode("ascii"),
        "secret_key_json": json.dumps(list(secret_bytes)),
    }

def generate_bitcoin_test_key() -> dict[str, str]:
    require_package("base58")
    require_package("cryptography")
    import base58
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.hashes import Hash

    private_key = ec.generate_private_key(ec.SECP256K1())
    private_bytes = private_key.private_numbers().private_value.to_bytes(32, "big")
    public_bytes = private_key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.CompressedPoint,
    )
    sha256 = Hash(__import__("cryptography").hazmat.primitives.hashes.SHA256())
    sha256.update(public_bytes)
    public_sha = sha256.finalize()

    ripemd160 = __import__("hashlib").new("ripemd160", public_sha).digest()
    payload = b"\x6f" + ripemd160  # Bitcoin testnet/signet P2PKH version
    checksum = __import__("hashlib").sha256(
        __import__("hashlib").sha256(payload).digest()
    ).digest()[:4]
    address = base58.b58encode(payload + checksum).decode("ascii")

    wif_payload = b"\xef" + private_bytes + b"\x01"
    wif_checksum = __import__("hashlib").sha256(
        __import__("hashlib").sha256(wif_payload).digest()
    ).digest()[:4]
    wif = base58.b58encode(wif_payload + wif_checksum).decode("ascii")

    return {
        "network": "testnet_or_signet",
        "address_p2pkh": address,
        "private_key_wif": wif,
        "public_key_compressed_hex": public_bytes.hex(),
    }

def upsert_account(manifest: dict[str, Any], name: str, factory) -> dict[str, str]:
    accounts = manifest.setdefault("accounts", {})
    if name not in accounts:
        accounts[name] = factory()
    return accounts[name]

def existing_env_values() -> dict[str, str]:
    if not ENV_FILE.exists():
        return {}
    values: dict[str, str] = {}
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    return values

def render_env(manifest: dict[str, Any]) -> str:
    existing = existing_env_values()
    accounts = manifest["accounts"]
    evm = accounts["evm_sepolia"]
    solana = accounts["solana_testnet"]
    flow = manifest["flow_testnet"]
    bitcoin = accounts["bitcoin_testnet"]

    lines = [
        "# GENERATED DEVELOPMENT-ONLY FILE. NEVER COMMIT.",
        "# Private keys below are for disposable testnet/signet accounts only.",
        "",
        "AETHER_NETWORK_ENV=development",
        "",
        f"EVM_SEPOLIA_RPC_URL={DEFAULTS['evm_testnet_rpc_url']}",
        f"EVM_SEPOLIA_ADDRESS={evm['address']}",
        f"EVM_SEPOLIA_PRIVATE_KEY={evm['private_key_hex']}",
        "",
        f"SOLANA_TESTNET_RPC_URL={DEFAULTS['solana_testnet_rpc_url']}",
        f"SOLANA_TESTNET_ADDRESS={solana['address']}",
        f"SOLANA_TESTNET_SECRET_KEY_BASE64={solana['secret_key_base64']}",
        "",
        f"FLOW_TESTNET_ACCESS_NODE_URL={existing.get('FLOW_TESTNET_ACCESS_NODE_URL', flow['access_node_url'])}",
        f"FLOW_TESTNET_ACCOUNT_ADDRESS={existing.get('FLOW_TESTNET_ACCOUNT_ADDRESS', flow['account_address'])}",
        f"FLOW_TESTNET_SIGNATURE_ALGORITHM={existing.get('FLOW_TESTNET_SIGNATURE_ALGORITHM', flow['signature_algorithm'])}",
        f"FLOW_TESTNET_HASH_ALGORITHM={existing.get('FLOW_TESTNET_HASH_ALGORITHM', flow['hash_algorithm'])}",
        "",
        f"BITCOIN_TESTNET_ESPLORA_URL={DEFAULTS['bitcoin_testnet_esplora_url']}",
        f"BITCOIN_SIGNET_ESPLORA_URL={DEFAULTS['bitcoin_signet_esplora_url']}",
        f"BITCOIN_TESTNET_ADDRESS={bitcoin['address_p2pkh']}",
        f"BITCOIN_TESTNET_PRIVATE_KEY_WIF={bitcoin['private_key_wif']}",
        "",
        "# Mainnet configuration intentionally contains public endpoints only.",
        "# Never place production mnemonics or private keys in this file.",
        "EVM_MAINNET_RPC_URL=",
        "SOLANA_MAINNET_RPC_URL=https://api.mainnet-beta.solana.com",
        "FLOW_MAINNET_ACCESS_NODE_URL=https://rest-mainnet.onflow.org",
        "BITCOIN_MAINNET_ESPLORA_URL=https://blockstream.info/api",
        "",
    ]
    return "\n".join(lines)

def write_env_if_changed(content: str) -> None:
    if ENV_FILE.exists() and ENV_FILE.read_text(encoding="utf-8") == content:
        ensure_mode_600(ENV_FILE)
        return
    temp = ENV_FILE.with_suffix(".tmp")
    temp.write_text(content, encoding="utf-8")
    ensure_mode_600(temp)
    temp.replace(ENV_FILE)
    ensure_mode_600(ENV_FILE)

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create/reuse disposable AetherAG development network accounts."
    )
    parser.add_argument(
        "--rotate",
        action="store_true",
        help="Create a fresh set of test-only accounts after confirmation.",
    )
    args = parser.parse_args()

    if args.rotate:
        answer = getpass.getpass(
            "Rotating replaces local disposable development keys. Type ROTATE to continue: "
        )
        if answer != "ROTATE":
            die("rotation cancelled")
        if MANIFEST_FILE.exists():
            MANIFEST_FILE.unlink()

    ensure_gitignore()
    SECRETS_DIR.mkdir(mode=0o700, exist_ok=True)
    os.chmod(SECRETS_DIR, 0o700)

    manifest = load_manifest()
    upsert_account(manifest, "evm_sepolia", generate_evm_account)
    upsert_account(manifest, "solana_testnet", generate_solana_account)
    manifest.setdefault("flow_testnet", {
        "account_address": os.environ.get("FLOW_TESTNET_ACCOUNT_ADDRESS", ""),
        "access_node_url": DEFAULTS["flow_testnet_access_node_url"],
        "signature_algorithm": "ECDSA_P256",
        "hash_algorithm": "SHA3_256",
    })
    upsert_account(manifest, "bitcoin_testnet", generate_bitcoin_test_key)

    save_manifest(manifest)
    write_env_if_changed(render_env(manifest))

    accounts = manifest["accounts"]
    print(f"Created/reused development secrets: {MANIFEST_FILE}")
    print(f"Created/reused development environment: {ENV_FILE}")
    print("")
    print("Fund these disposable addresses only:")
    print(f"  EVM Sepolia:      {accounts['evm_sepolia']['address']}")
    print(f"  Solana testnet:   {accounts['solana_testnet']['address']}")
    print(f"  Bitcoin testnet:  {accounts['bitcoin_testnet']['address_p2pkh']}")
    flow_address = existing_env_values().get("FLOW_TESTNET_ACCOUNT_ADDRESS", "")
    if flow_address:
        print(f"  Flow testnet:    {flow_address}")
    else:
        print("  Flow testnet:    configure FLOW_TESTNET_ACCOUNT_ADDRESS separately")
    print("")
    print("Load variables only in the current shell with:")
    print("  set -a; source .env.development.local; set +a")
    print("")
    print("Flow requires a separately funded testnet payer to create the on-chain account.")
    print("Do not put a production payer key, mnemonic, or mainnet private key in this file.")

if __name__ == "__main__":
    main()
