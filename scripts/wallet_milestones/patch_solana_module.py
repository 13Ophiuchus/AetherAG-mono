import re
import sys
from pathlib import Path

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Sources/AetherWalletKit/Data/SolanaModule/SolanaModule.swift"

# Matches the retrievePrivateKey(for: "masterKey") call inline, tolerant of
# surrounding whitespace/variable-name differences.
CALL_PATTERN = re.compile(
    r'retrievePrivateKey\(for:\s*"masterKey"\)'
)

NEW_CALL = 'retrievePrivateKey(for: chain.chainId)'

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1

    text = TARGET.read_text()

    if NEW_CALL in text and not CALL_PATTERN.search(text):
        print("Already patched; nothing to do.")
        return 0

    if not CALL_PATTERN.search(text):
        print("Expected retrievePrivateKey(for: \"masterKey\") call not found; aborting.")
        return 1

    backup = TARGET.with_suffix(TARGET.suffix + ".bak")
    if not backup.exists():
        backup.write_text(text)

    patched = CALL_PATTERN.sub(NEW_CALL, text)
    TARGET.write_text(patched)

    print(f"Patched: {TARGET}")
    print(f"Backup:  {backup}")
    print("NOTE: verify the enclosing function receives 'chain: ChainConfig' as a parameter;")
    print("      if it takes a different parameter name, adjust chain.chainId accordingly.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
