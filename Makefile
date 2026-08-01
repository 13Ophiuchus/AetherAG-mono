.PHONY: preflight lint build-linux

preflight:
	@bash scripts/linux-preflight.sh

lint: preflight

build-linux:
	@echo "→ Building AetherAG (Linux simulation via swift build)..."
	cd AetherAG && swift build 2>&1

