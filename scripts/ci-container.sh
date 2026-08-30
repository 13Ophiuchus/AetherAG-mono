#!/usr/bin/env zsh
set -euo pipefail
MONO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="aether-server:ci-${GITHUB_SHA:-local}"
echo "==> swift build (native)..."
(cd "$MONO/AetherAG" && swift build -c release --product AetherAGMailServerRun)
echo "==> container build (prebuilt)..."
container build -f "$MONO/Containerfile.prebuilt" -t "$IMAGE" "$MONO"
container run --rm "$IMAGE" ./AetherAGMailServerRun --help | head -5
echo "CI build passed ✅"
