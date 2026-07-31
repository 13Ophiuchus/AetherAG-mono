import re
import sys
from pathlib import Path

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Tests/AetherWalletKitTests/SolanaModuleTests.swift"

OLD_CALL = re.compile(r'storePrivateKey\(masterKey, for: "masterKey", requiresBiometrics: false\)')
NEW_CALL = 'storePrivateKey(masterKey, for: chain.chainId, requiresBiometrics: false)'

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1

    text = TARGET.read_text()

    if NEW_CALL in text and not OLD_CALL.search(text):
        print("Already patched; nothing to do.")
        return 0

    if not OLD_CALL.search(text):
        print("Expected call site not found; aborting.")
        return 1

    backup = TARGET.with_suffix(TARGET.suffix + ".bak")
    if not backup.exists():
        backup.write_text(text)

    patched = OLD_CALL.sub(NEW_CALL, text)
    TARGET.write_text(patched)

    print(f"Patched {TARGET}")
    print(f"Backup:  {backup}")
    print("NOTE: confirm each test has a `chain` variable of type ChainConfig in scope near each call site.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
