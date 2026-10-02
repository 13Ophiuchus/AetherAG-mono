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
if [ -n "$ISSUER_ES256_PUBLIC_KEY_PEM_B64" ]; then
  export ISSUER_ES256_PUBLIC_KEY_PEM="$(printf '%s' "$ISSUER_ES256_PUBLIC_KEY_PEM_B64" | base64 -d)"
fi
