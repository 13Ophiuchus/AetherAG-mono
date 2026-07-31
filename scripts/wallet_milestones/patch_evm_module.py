import re
import sys
from pathlib import Path

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Sources/AetherWalletKit/Data/EVMModule/EVMModule.swift"

FUNC_PATTERN = re.compile(
    r'private func getPrivateKeyData\(for chain: ChainConfig\) async throws -> Data \{.*?\n\t\}',
    re.DOTALL,
)

NEW_FUNC = (
    'private func getPrivateKeyData(for chain: ChainConfig) async throws -> Data {\n'
    '\t\tguard let keyData = try await keyManager.retrievePrivateKey(for: chain.chainId) else {\n'
    '\t\t\tthrow WalletError.keychainError("Private key not found for \\(chain.name)")\n'
    '\t\t}\n'
    '\t\treturn keyData\n'
    '\t}'
)

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1

    text = TARGET.read_text()

    match = FUNC_PATTERN.search(text)
    if not match:
        print("Could not locate getPrivateKeyData(for:) function body via regex; aborting.")
        return 1

    if 'chain.chainId' in match.group(0):
        print("Already patched; nothing to do.")
        return 0

    backup = TARGET.with_suffix(TARGET.suffix + ".bak")
    if not backup.exists():
        backup.write_text(text)

    patched = text[:match.start()] + NEW_FUNC + text[match.end():]
    TARGET.write_text(patched)

    print(f"Patched: {TARGET}")
    print(f"Backup:  {backup}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
