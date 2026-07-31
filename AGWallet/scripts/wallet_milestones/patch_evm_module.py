from pathlib import Path
import sys

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Sources/AetherWalletKit/Data/EVMModule/EVMModule.swift"

OLD_SNIPPET = """\tprivate func getPrivateKeyData(for chain: ChainConfig) async throws -> Data {
\t\t// This assumes the master key is the EVM private key.
\t\t// A real implementation would use the derivation path.
\t\tguard let keyData = try await keyManager.retrievePrivateKey(for: "masterKey") else {
\t\t\tthrow WalletError.keychainError("Master key not found")
\t\t}
\t\treturn keyData
\t}"""

NEW_SNIPPET = """\tprivate func getPrivateKeyData(for chain: ChainConfig) async throws -> Data {
\t\tguard let keyData = try await keyManager.retrievePrivateKey(for: chain.chainId) else {
\t\t\tthrow WalletError.keychainError("Private key not found for \\(chain.name)")
\t\t}
\t\treturn keyData
\t}"""

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1

    text = TARGET.read_text()

    if NEW_SNIPPET in text:
        print("Already patched; nothing to do.")
        return 0

    if OLD_SNIPPET not in text:
        print("Expected old snippet not found exactly; refusing to patch.")
        return 1

    backup = TARGET.with_suffix(TARGET.suffix + ".bak")
    if not backup.exists():
        backup.write_text(text)

    patched = text.replace(OLD_SNIPPET, NEW_SNIPPET, 1)
    TARGET.write_text(patched)

    print(f"Patched: {TARGET}")
    print(f"Backup:  {backup}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
