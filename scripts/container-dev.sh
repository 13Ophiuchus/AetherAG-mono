#!/usr/bin/env zsh
set -euo pipefail
# Builds native release binary then packages into ubuntu:24.04 runtime image.
# Avoids apple container CLI 1.2.2 buildkit /tmp bug by using prebuilt binary.
MONO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="aether-server:dev"
NAME="aether-dev"

if [[ "${1:-}" == "rebuild" ]]; then
  echo "==> swift build (native)..."
  (cd "$MONO/AetherAG" && swift build -c release --product AetherAGMailServerRun)
  echo "==> container build (prebuilt)..."
  container build -f "$MONO/Containerfile.prebuilt" -t "$IMAGE" "$MONO"
fi

PG_IP=$(container inspect pg-test 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    print(d.get('network',{}).get('interfaces',{}).get('eth0',{}).get('ipv4',{}).get('address','192.168.64.2'))" \
  2>/dev/null || echo "192.168.64.2")

container stop "$NAME" 2>/dev/null || true
container rm   "$NAME" 2>/dev/null || true

container run -d --name "$NAME" -p 8080:8080 \
  -e DATABASE_URL="postgresql://postgres:postgres@${PG_IP}:5432/aether_dev" \
  -e ENVIRONMENT="development" \
  -e JWT_SECRET="${JWT_SECRET:-dev-secret-change-me}" \
  "$IMAGE"

echo "aether-dev running → http://localhost:8080"
container logs -f "$NAME"
