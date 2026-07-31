import re
import sys
from pathlib import Path

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Tests/AetherWalletKitTests/EVMModuleTests.swift"

OLD = '"Master key not found"'
NEW = '"Private key not found for Ethereum"'

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1
    text = TARGET.read_text()
    if NEW in text and OLD not in text:
        print("Already patched; nothing to do.")
        return 0
    if OLD not in text:
        print("Expected literal not found; aborting.")
        return 1
    backup = TARGET.with_suffix(TARGET.suffix + ".bak")
    if not backup.exists():
        backup.write_text(text)
    count = text.count(OLD)
    patched = text.replace(OLD, NEW)
    TARGET.write_text(patched)
    print(f"Replaced {count} occurrence(s) of {OLD} with {NEW}")
    print(f"Patched: {TARGET}")
    print(f"Backup:  {backup}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
