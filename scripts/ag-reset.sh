#!/usr/bin/env bash
set -euo pipefail

BRIDGE_URL="${AG_BRIDGE_HOST:-http://127.0.0.1:19999}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/ensure-bridge.sh" >/dev/null
curl -fsS -X POST "$BRIDGE_URL/new" -H 'Content-Type: application/json' -d '{}'
