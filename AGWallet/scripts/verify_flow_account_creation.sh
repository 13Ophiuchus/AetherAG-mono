#!/usr/bin/env bash
set -euo pipefail
ID="${1:?usage: verify_flow_account_creation.sh <tx_id | account_address>}"
BASE="https://rest-testnet.onflow.org/v1"

if [ "${#ID}" -eq 64 ]; then
  export RES="$(curl -sf "$BASE/transaction_results/$ID")"
  ADDR="$(python3 - << 'PY'
import json, os, base64
res = json.loads(os.environ["RES"])
assert res["status"] == "Sealed" and res["execution"] == "Success" and not res["error_message"], res
ev = next(e for e in res["events"] if e["type"] == "flow.AccountCreated")
a = json.loads(base64.b64decode(ev["payload"]))["value"]["fields"][0]["value"]["value"]
print(a[2:] if a.startswith("0x") else a)
PY
)"
else
  ADDR="${ID#0x}"
fi

export KEYS="$(curl -sf "$BASE/accounts/$ADDR?expand=keys")"
ADDR="$ADDR" python3 - << 'PY'
import json, os
key = json.loads(os.environ["KEYS"])["keys"][0]
assert key["signing_algorithm"] == "ECDSA_P256", key
assert key["hashing_algorithm"] == "SHA3_256", key
assert key["weight"] == "1000" and not key["revoked"], key
print(f"OK  account=0x{os.environ['ADDR']}  key0={key['signing_algorithm']}/{key['hashing_algorithm']} weight={key['weight']}")
PY
