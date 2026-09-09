#!/usr/bin/env zsh
set -euo pipefail
MONO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="aether-server:ci-${GITHUB_SHA:-local}"
echo "==> container build (multi-stage, Linux)..."
container build -f "$MONO/Containerfile" -t "$IMAGE" "$MONO"
container run --rm --env-file "$MONO/AetherAG/.env" "$IMAGE" ./AetherAGMailServerRun --help | head -5
echo "CI build passed ✅"
