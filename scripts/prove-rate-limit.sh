#!/usr/bin/env bash
set -euo pipefail

cd /Users/nicreich/AetherAG-mono

mkdir -p .artifacts/logs .artifacts/tmp
ts="$(date +%Y%m%d-%H%M%S)"
burst_log=".artifacts/logs/rate-limit-burst-${ts}.log"
body_file=".artifacts/tmp/invalid-preauth-token.json"

cat > "$body_file" <<'JSON'
{"grant_type":"urn:ietf:params:oauth:grant-type:pre-authorized_code","pre-authorized_code":"invalid"}
JSON

docker exec aetherag-redis redis-cli FLUSHALL >/dev/null
: > "$burst_log"

for request_number in $(seq 1 25); do
  http_code="$(
    curl \
      --silent \
      --output ".artifacts/tmp/rate-limit-response-${request_number}.json" \
      --write-out '%{http_code}' \
      --request POST \
      --url 'http://127.0.0.1:8080/oid4vci/token' \
      --header 'content-type: application/json' \
      --header 'x-forwarded-for: 203.0.113.77' \
      --data-binary "@${body_file}"
  )"

  printf 'request=%02d http_code=%s\n' \
    "$request_number" "$http_code" | tee -a "$burst_log"
done

printf '\n--- Redis keys ---\n' | tee -a "$burst_log"
docker exec aetherag-redis redis-cli --scan --pattern 'oid4vci:rl:*' \
  | tee -a "$burst_log"

if grep -q 'http_code=429' "$burst_log"; then
  printf '\nPASS: HTTP 429 was observed.\n'
else
  printf '\nFAIL: no HTTP 429 was observed.\n' >&2
  exit 1
fi
