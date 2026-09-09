#!/usr/bin/env zsh
set -euo pipefail
# Builds the multi-stage Linux image (swift:6.2-noble builder + ubuntu:24.04 runtime)
# via the canonical Containerfile, verified working end-to-end 2026-09-02.
MONO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="aether-server:dev"
NAME="aether-dev"

if [[ "${1:-}" == "rebuild" ]]; then
  echo "==> container build (multi-stage, Linux)..."
  container build -f "$MONO/Containerfile" -t "$IMAGE" "$MONO"
fi

PG_IP=$(container inspect pg-test 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); c=d[0] if isinstance(d,list) else d; \
    nets=c.get('status',{}).get('networks',[]); \
    print(nets[0]['ipv4Address'].split('/')[0] if nets else '192.168.64.5')" \
  2>/dev/null || echo "192.168.64.5")

container stop "$NAME" 2>/dev/null || true
container rm   "$NAME" 2>/dev/null || true

container run -d --name "$NAME" -p 8080:8080 \
  --env-file "$MONO/AetherAG/.env" \
  -e USE_IN_MEMORY_DB=false \
  -e DATABASE_URL="postgresql://postgres:postgres@${PG_IP}:5432/aether_dev" \
  "$IMAGE"

echo "aether-dev running → http://localhost:8080"
container logs -f "$NAME"
