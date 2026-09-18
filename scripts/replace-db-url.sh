#!/usr/bin/env bash
set -euo pipefail

: "${NEW_DATABASE_URL:?Set NEW_DATABASE_URL first}"
: "${README_PATH:?Set README_PATH first}"
: "${PLACEHOLDER:?Set PLACEHOLDER first}"

if ! grep -qF "$PLACEHOLDER" "$README_PATH"; then
  echo "Placeholder URL not found in $README_PATH"
  exit 0
fi

python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ["README_PATH"])
placeholder = os.environ["PLACEHOLDER"]
replacement = os.environ["NEW_DATABASE_URL"]

text = path.read_text()
count = text.count(placeholder)
path.write_text(text.replace(placeholder, replacement))
print(f"Replaced {count} occurrence(s) in {path}")
PY
