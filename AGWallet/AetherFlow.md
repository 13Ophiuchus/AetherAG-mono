# Aether Flow Key & Account Runbook

Create new Flow keys, create and fund a testnet account, store everything securely,
and access it without leaving secrets in git or terminal history.

Shell: zsh (macOS). Network: testnet. Run from `~/AetherAG-mono` unless noted.

---

## 0. Rules

1. Never paste private keys, secrets, or `.env` contents into chats, tickets, or commits.
2. The Keychain is the source of truth. `.env` files are disposable output.
3. One environment label per key set: `DEV`, `STAGING`, `PROD`. Never reuse keys across labels.
4. Testnet keys never go into anything labeled production.
5. The mnemonic is the only way to rebuild the key from words. Store it offline.

---

## 1. Prerequisites

```bash
command -v flow     >/dev/null || brew install flow-cli
command -v openssl  >/dev/null || brew install openssl
command -v python3  >/dev/null || brew install python
flow version
```

Set the environment label and helper functions. Run these in every new terminal.

```bash
export AENV=DEV

kc_put() { security add-generic-password -U -a "$USER" -s "AETHER_${AENV}_$1" -w "$2"; }
kc_get() { security find-generic-password -a "$USER" -s "AETHER_${AENV}_$1" -w 2>/dev/null; }
kc_has() { security find-generic-password -a "$USER" -s "AETHER_${AENV}_$1" >/dev/null 2>&1; }
```

Note: `-U` overwrites an existing item with the same name. If a key set already exists
for this label and you want to keep it, change `AENV` (for example `DEV2`) before step 2.

---

## 2. Generate new keys

### 2.1 Flow account key (ECDSA_P256)

```bash
umask 077
T=$(mktemp -d); chmod 700 "$T"
flow keys generate --sig-algo ECDSA_P256 --output json > "$T/k.json"
python3 -c 'import json,sys; print("fields:", list(json.load(open(sys.argv))))' "$T/k.json"[3]
```

Expected fields: `derivationPath`, `mnemonic`, `private`, `public`.

```bash
getf() { python3 -c 'import json,sys; print(json.load(open(sys.argv))[sys.argv])' "$T/k.json" "$1"; }[4][3]
kc_put FLOW_ISSUER_PRIVATE_KEY "$(getf private)"
kc_put FLOW_ISSUER_PUBLIC_KEY  "$(getf public)"
kc_put FLOW_ISSUER_MNEMONIC    "$(getf mnemonic)"
kc_put FLOW_ISSUER_DERIVATION  "$(getf derivationPath)"
```

### 2.2 Application secrets

```bash
kc_put JWT_HS256_SECRET "$(openssl rand -base64 48)"
kc_put JWT_HMAC_KEY     "$(openssl rand -base64 32)"
kc_put JWT_CURRENT_KID  "k-$(date +%Y%m%d)-$(openssl rand -hex 3)"
```

### 2.3 Ed25519 issuer key

```bash
openssl genpkey -algorithm ED25519 -out "$T/ed.pem"
kc_put ISSUER_ED25519_PRIVATE_KEY_BASE64URL "$(openssl pkey -in "$T/ed.pem" -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=\n')"
kc_put ISSUER_ED25519_PUBLIC_KEY_BASE64URL  "$(openssl pkey -in "$T/ed.pem" -pubout -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=\n')"
```

### 2.4 ES256 issuer key (P-256 PEM)

```bash
openssl ecparam -name prime256v1 -genkey -noout | openssl pkcs8 -topk8 -nocrypt -out "$T/es.pem"
kc_put ISSUER_ES256_PRIVATE_KEY_PEM_B64 "$(base64 < "$T/es.pem" | tr -d '\n')"
kc_put ISSUER_ES256_PUBLIC_KEY_PEM_B64  "$(openssl pkey -in "$T/es.pem" -pubout | base64 | tr -d '\n')"
```

### 2.5 Back up the mnemonic offline, then destroy temp files

Write the mnemonic on paper (or an encrypted password manager entry) now:

```bash
kc_get FLOW_ISSUER_MNEMONIC
```

Then clear the screen and remove temp files:

```bash
clear
rm -rf "$T"; unset T
printf 'Public key length (expect 128): '; kc_get FLOW_ISSUER_PUBLIC_KEY | tr -d '\n' | wc -c
```

---

## 3. Create the testnet account

### 3.1 Open the faucet with the public key prefilled

```bash
PUB=$(kc_get FLOW_ISSUER_PUBLIC_KEY)
echo "$PUB" | pbcopy
open "[https://testnet-faucet.onflow.org/?key=$PUB](https://testnet-faucet.onflow.org/?key=$PUB)"
unset PUB
```

In the browser: keep Signature `ECDSA_P256` and Hash `SHA3_256`, complete the check, and click Create Account.
Copy the address shown. Clear the clipboard afterward: `pbcopy < /dev/null`.

### 3.2 Save the address and key index

```bash
printf 'New testnet address (with or without 0x): '; read -r ADDR
ADDR=${ADDR#0x}
[[ "$ADDR" =~ ^[0-9a-fA-F]{16}$ ]] || { echo "Not a 16-hex-char address"; unset ADDR; }
```

Only continue if no error was printed.

```bash
kc_put FLOW_ISSUER_ADDRESS   "$ADDR"
kc_put FLOW_ISSUER_KEY_INDEX 0
kc_put FLOW_CHAIN_ID         testnet
pbcopy < /dev/null
```

### 3.3 Verify on-chain

```bash
A=$(kc_get FLOW_ISSUER_ADDRESS)
curl -s "[https://rest-testnet.onflow.org/v1/accounts/0x$A?expand=keys](https://rest-testnet.onflow.org/v1/accounts/0x$A?expand=keys)" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("balance:", int(d["balance"])/1e8, "FLOW")
for k in d["keys"]:
    print("key", k["index"], k["signing_algorithm"], k["hashing_algorithm"], "weight", k["weight"], "revoked", k.get("revoked"))'
```

Expect: key 0, `ECDSA_P256`, `SHA3_256`, weight 1000, revoked False.
Also confirm the on-chain public key matches yours:

```bash
curl -s "[https://rest-testnet.onflow.org/v1/accounts/0x$A?expand=keys](https://rest-testnet.onflow.org/v1/accounts/0x$A?expand=keys)" | python3 -c '
import json,sys
d=json.load(sys.stdin); k=d["keys"]["public_key"].removeprefix("0x")
print("matches Keychain:", k == sys.argv.removeprefix("0x"))' "$(kc_get FLOW_ISSUER_PUBLIC_KEY)"[3]
```

---

## 4. Fund the account

The faucet funds a new account at creation. To top up an existing one:

```bash
flow accounts fund "$(kc_get FLOW_ISSUER_ADDRESS)"
```

If the browser does not open, use:
`https://testnet-faucet.onflow.org/fund-account?address=<ADDRESS_WITHOUT_0x>`

Check the balance again with step 3.3. Accounts under about 0.001 FLOW cannot pay
transaction fees, which makes later key revocation fail silently.

---

## 5. Save non-secret settings

These are not secrets. Keep them in the same place for consistency.

```bash
kc_put ISSUER_BASE_URL  "http://localhost:8080"
kc_put REDIS_URL        "redis://localhost:6379"
kc_put DATABASE_URL     "postgres://localhost:5432/aetherag"
```

Edit values to match your setup. Production values must be different and set under `AENV=PROD`.

---

## 6. Access secrets securely

### 6.1 Preferred: load into the current shell only (no file)

Create `scripts/load-aether-env.sh`:

```bash
mkdir -p scripts
cat > scripts/load-aether-env.sh <<'EOF'
#!/usr/bin/env bash
# Usage: source scripts/load-aether-env.sh DEV
AENV="${1:-DEV}"
for n in FLOW_CHAIN_ID FLOW_ISSUER_ADDRESS FLOW_ISSUER_KEY_INDEX FLOW_ISSUER_PRIVATE_KEY \
         JWT_HS256_SECRET JWT_HMAC_KEY JWT_CURRENT_KID \
         ISSUER_ED25519_PRIVATE_KEY_BASE64URL ISSUER_ED25519_PUBLIC_KEY_BASE64URL \
         ISSUER_ES256_PRIVATE_KEY_PEM_B64 ISSUER_ES256_PUBLIC_KEY_PEM_B64 \
         ISSUER_BASE_URL REDIS_URL DATABASE_URL; do
  v=$(security find-generic-password -a "$USER" -s "AETHER_${AENV}_${n}" -w 2>/dev/null) && export "$n=$v"
done
echo "loaded $(env | grep -cE '^(FLOW_|JWT_|ISSUER_|REDIS_URL|DATABASE_URL)') variables for $AENV"
EOF
chmod 700 scripts/load-aether-env.sh
```

Use it in a subshell so secrets disappear when the command ends:

```bash
( source scripts/load-aether-env.sh DEV && swift run )
```

### 6.2 Optional: generate a `.env` file on demand

Use this only if a tool requires a file. The file is owner-readable only and must be git-ignored.

```bash
OUT=.env.local
git check-ignore -q "$OUT" || { echo "$OUT is NOT git-ignored. Fix .gitignore first."; false; }
```

Only continue if that printed nothing.

```bash
umask 077
{
  for n in FLOW_CHAIN_ID FLOW_ISSUER_ADDRESS FLOW_ISSUER_KEY_INDEX FLOW_ISSUER_PRIVATE_KEY \
           JWT_HS256_SECRET JWT_HMAC_KEY JWT_CURRENT_KID \
           ISSUER_ED25519_PRIVATE_KEY_BASE64URL ISSUER_ED25519_PUBLIC_KEY_BASE64URL \
           ISSUER_ES256_PRIVATE_KEY_PEM_B64 ISSUER_ES256_PUBLIC_KEY_PEM_B64 \
           ISSUER_BASE_URL REDIS_URL DATABASE_URL; do
    printf '%s=%s\n' "$n" "$(kc_get "$n")"
  done
} > "$OUT"
chmod 600 "$OUT"
ls -l "$OUT"
```

Delete the file when finished: `rm -P .env.local`.

### 6.3 Required .gitignore entries

Add to the root repo and to `AetherAG/` (a submodule has its own `.gitignore`):

```bash
for d in . AetherAG; do
  printf '%s\n' '.env' '.env.*' '!.env.example' '!.env.*.example' '*.pkey' '*private*.pem' 'generated-key*' >> "$d/.gitignore"
done
git check-ignore -v .env.local AetherAG/.env.local
```

### 6.4 Safe viewing

Show names only, never values:

```bash
security dump-keychain login.keychain-db 2>/dev/null | grep -o "AETHER_${AENV}_[A-Z0-9_]*" | sort -u
```

Show one value deliberately:

```bash
kc_get FLOW_ISSUER_ADDRESS
```

---

## 7. Encrypted backup

Create an encrypted bundle of every secret for this environment. Store it on an external drive,
not in the repo or a synced folder you do not control.

```bash
umask 077
BK=$(mktemp -d); chmod 700 "$BK"
for n in FLOW_ISSUER_PRIVATE_KEY FLOW_ISSUER_PUBLIC_KEY FLOW_ISSUER_MNEMONIC FLOW_ISSUER_ADDRESS \
         FLOW_ISSUER_KEY_INDEX FLOW_CHAIN_ID JWT_HS256_SECRET JWT_HMAC_KEY JWT_CURRENT_KID \
         ISSUER_ED25519_PRIVATE_KEY_BASE64URL ISSUER_ES256_PRIVATE_KEY_PEM_B64; do
  printf '%s=%s\n' "$n" "$(kc_get "$n")" >> "$BK/bundle.txt"
done
openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "$BK/bundle.txt" -out "AETHER_${AENV}_backup_$(date +%Y%m%d).enc"
rm -rf "$BK"; unset BK
ls -l AETHER_${AENV}_backup_*.enc
```

You will be prompted for a passphrase. Use a long one and store it separately from the file.
Move the `.enc` file out of the repo immediately.

Restore test (prints names only):

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in AETHER_DEV_backup_YYYYMMDD.enc | sed -E 's/=.*/=<hidden>/'
```

---

## 8. Rotation and revocation

Rotate on a schedule or immediately after any suspected leak.

1. Generate a new key set under a new label (`AENV=DEV2`) using step 2.
2. Create or fund a new account for it (steps 3 and 4), or add the new key to the existing account.
3. Move anything of value to the new account.
4. Revoke the old key on the old account. Keep the old signing key available until this succeeds.

Revoke transaction (`revoke.cdc`):

```bash
cat > /tmp/revoke.cdc <<'EOF'
transaction(keyIndex: Int) {
  prepare(signer: auth(RevokeKey) &Account) {
    signer.keys.revoke(keyIndex: keyIndex)
  }
}
EOF
```

Run it with a temporary config that is deleted afterward. The account must hold enough FLOW for fees.

```bash
OLD=<OLD_ADDRESS_WITHOUT_0x>
OLD_KEY_LABEL=DEV
D=$(mktemp -d); chmod 700 "$D"; cp /tmp/revoke.cdc "$D/r.cdc"
cat > "$D/flow.json" <<EOF
{
  "networks": { "testnet": "access.devnet.nodes.onflow.org:9000" },
  "accounts": { "old": { "address": "$OLD", "key": {
    "type": "hex", "index": 0, "signatureAlgorithm": "ECDSA_P256", "hashAlgorithm": "SHA3_256",
    "privateKey": "$(security find-generic-password -a "$USER" -s AETHER_${OLD_KEY_LABEL}_FLOW_ISSUER_PRIVATE_KEY -w)" } } }
}
EOF
chmod 600 "$D/flow.json"
flow transactions send "$D/r.cdc" --args-json '[{"type":"Int","value":"0"}]' --network testnet --signer old -f "$D/flow.json"
rm -rf "$D" /tmp/revoke.cdc
```

Always verify afterward, because the CLI can return success even when the transaction did not take effect:

```bash
curl -s "[https://rest-testnet.onflow.org/v1/accounts/0x$OLD?expand=keys](https://rest-testnet.onflow.org/v1/accounts/0x$OLD?expand=keys)" | python3 -c '
import json,sys
for k in json.load(sys.stdin)["keys"]: print("key", k["index"], "revoked", k.get("revoked"))'
```

Flow accounts cannot be deleted. A revoked-key account with no remaining keys is permanently unusable.

---

## 9. Leak checks

Before every commit:

```bash
git diff --cached --name-only | grep -iE '\.env|\.pem|\.pkey|generated-key|\.log$' && echo "STOP: sensitive filename staged"
git diff --cached | grep -iE 'PRIVATE_KEY=|SECRET=|BEGIN (EC |RSA )?PRIVATE KEY' && echo "STOP: secret-like content staged"
```

Install it as a pre-commit hook:

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
if git diff --cached --name-only | grep -iE '\.env($|\.)|\.pem$|\.pkey$|generated-key'; then
  echo "Blocked: sensitive file staged"; exit 1
fi
if git diff --cached | grep -iE '^\+.*(PRIVATE_KEY=[0-9a-fA-F]{16,}|BEGIN (EC |RSA )?PRIVATE KEY)'; then
  echo "Blocked: secret-like content staged"; exit 1
fi
EOF
chmod +x .git/hooks/pre-commit
```

Clear terminal history of anything sensitive:

```bash
: > ~/.zsh_history && fc -R
```

---

## 10. Quick reference

| Task | Command |
|---|---|
| Load secrets for a command | `( source scripts/load-aether-env.sh DEV && <cmd> )` |
| Show account | `curl -s "https://rest-testnet.onflow.org/v1/accounts/0x$(kc_get FLOW_ISSUER_ADDRESS)?expand=keys"` |
| Top up testnet funds | `flow accounts fund "$(kc_get FLOW_ISSUER_ADDRESS)"` |
| List stored items | `security dump-keychain login.keychain-db \| grep -o "AETHER_${AENV}_[A-Z0-9_]*" \| sort -u` |
| Delete one item | `security delete-generic-password -a "$USER" -s AETHER_DEV_<NAME>` |
| Remove generated `.env` | `rm -P .env.local` |

## 11. Troubleshooting

- `unknown flag: --hash-algo`: `flow keys generate` does not take a hash flag. Choose SHA3_256 in the faucet.
- `CERTIFICATE_VERIFY_FAILED` from Python: run the `Install Certificates.command` that ships with the python.org installer, or use `curl`.
- Revoke "succeeds" but key still shows `revoked False`: the account likely lacks the balance to pay fees. Fund it and retry.
- `security: SecKeychainSearchCopyNext: item could not be found`: wrong `AENV` label or the item was never saved.
- Address check fails: it must be exactly 16 hex characters after removing `0x`.
