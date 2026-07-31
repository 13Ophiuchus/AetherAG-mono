import re
import sys
from pathlib import Path

ROOT = Path("/Users/nicreich/AetherAG-mono")
TARGET = ROOT / "AGWallet/Tests/AetherWalletKitTests/SolanaModuleTests.swift"

USE_LINE = "        try await keyManager.storePrivateKey(masterKey, for: chain.chainId, requiresBiometrics: false)"
DECL_LINE = "        let chain = ChainConfig.mockSolanaChain()"
MARKER = "__CHAIN_DECL_INSERTED__"

def insert_decl_before_each_use(text: str) -> tuple[str, int]:
    # Insert a chain declaration immediately before every use-line occurrence,
    # tagging inserted lines so we can dedupe later within the same function.
    parts = text.split(USE_LINE)
    if len(parts) <= 1:
        return text, 0
    rebuilt = parts[0]
    inserted = 0
    for part in parts[1:]:
        rebuilt += DECL_LINE + "  " + MARKER + "\n" + USE_LINE + part
        inserted += 1
    return rebuilt, inserted

def dedupe_per_function(text: str) -> str:
    # Split on function boundaries; within each function body, if the
    # marked inserted decl is followed later by an unmarked identical decl
    # (the pre-existing one further down), drop the redundant pre-existing one.
    func_pattern = re.compile(r'(func \w+\([^\n]*\n(?:.*?\n)*?    \})', re.DOTALL)

    def process_func(match: re.Match) -> str:
        body = match.group(1)
        if MARKER not in body:
            return body
        lines = body.split("\n")
        seen_marked = False
        out = []
        for line in lines:
            stripped = line.strip()
            is_decl = stripped == DECL_LINE.strip()
            is_marked = MARKER in line
            if is_marked:
                seen_marked = True
                out.append(line.replace("  " + MARKER, ""))
                continue
            if is_decl and seen_marked:
                # duplicate pre-existing declaration after our inserted one; drop it
                continue
            out.append(line)
        return "\n".join(out)

    return func_pattern.sub(process_func, text)

def main() -> int:
    if not TARGET.exists():
        print(f"Target not found: {TARGET}")
        return 1

    text = TARGET.read_text()

    if MARKER in text:
        print("Marker found unexpectedly; a previous run may have failed midway. Aborting.")
        return 1

    if "cannot find 'chain' in scope" in text:
        pass  # not a real check, just placeholder guard

    already_ok = (text.count(USE_LINE) > 0) and all(
        DECL_LINE in text.split(USE_LINE)[i] if False else True for i in range(1)
    )

    backup = TARGET.with_suffix(TARGET.suffix + ".bak2")
    if not backup.exists():
        backup.write_text(text)

    patched, n = insert_decl_before_each_use(text)
    if n == 0:
        print("No un-scoped 'chain.chainId' use-lines found; nothing to insert.")
        return 0

    patched = dedupe_per_function(patched)

    if MARKER in patched:
        print("ERROR: marker still present after dedupe pass; aborting write to avoid corrupting file.")
        return 1

    TARGET.write_text(patched)
    print(f"Inserted {n} 'let chain = ChainConfig.mockSolanaChain()' declaration(s) before use sites.")
    print(f"Deduped any resulting redundant declarations within the same function.")
    print(f"Patched: {TARGET}")
    print(f"Backup:  {backup}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
