#!/usr/bin/env bash
set -euo pipefail

cd /Users/nicreich/AetherAG-mono
mkdir -p .artifacts/logs

ts="$(date +%Y%m%d-%H%M%S)"
server_log=".artifacts/logs/rate-limit-server-${ts}.log"
pid_file=".artifacts/aetherag-rate-limit.pid"

if [[ -f "$pid_file" ]]; then
  previous_pid="$(cat "$pid_file")"
  kill "$previous_pid" >/dev/null 2>&1 || true
  rm -f "$pid_file"
fi

unset USE_IN_MEMORY_DB
unset USEINMEMORYDB
unset REDISURL

export DATABASE_URL='postgresql://aetherag:aetherag-local-only@127.0.0.1:5432/aetherag'
export REDIS_URL='redis://127.0.0.1:6379'
export ENABLE_DEV_ROUTES='true'

export ISSUER_BASE_URL='http://127.0.0.1:8080'
export FLOW_ISSUER_ADDRESS='0x0000000000000001'
export FLOW_ISSUER_PRIVATE_KEY='test-private-key'
export FLOW_ISSUER_KEY_INDEX='0'
export FLOW_CHAIN_ID='testnet'
export JWT_HS256_SECRET='test-secret'
export JWT_CURRENT_KID='v1'

swift run --package-path AetherAG AetherAGMailServerRun >"$server_log" 2>&1 &
server_pid="$!"
printf '%s\n' "$server_pid" > "$pid_file"

for _ in $(seq 1 90); do
  if curl --fail --silent http://127.0.0.1:8080/health >/dev/null 2>&1; then
    printf 'READY\npid=%s\nlog=%s\n' "$server_pid" "$server_log"
    exit 0
  fi

  if ! kill -0 "$server_pid" >/dev/null 2>&1; then
    echo "Server exited during startup." >&2
    tail -n 160 "$server_log" >&2 || true
    exit 1
  fi

  sleep 1
done

echo "Timed out waiting for /health." >&2
tail -n 160 "$server_log" >&2 || true
exit 1
