#!/usr/bin/env bash
set -euo pipefail

BRIDGE_URL="${AG_BRIDGE_HOST:-http://127.0.0.1:19999}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
START_SCRIPT="$REPO_DIR/scripts/start_antigravity.sh"
TMP_HEALTH="/tmp/antigravity_bridge_skill_health.json"
TMP_START_LOG="/tmp/antigravity_bridge_skill_start.log"

check_health() {
  curl -fsS "$BRIDGE_URL/health" >"$TMP_HEALTH" || return 1
  cat "$TMP_HEALTH"
}

if check_health >/dev/null 2>&1; then
  cat "$TMP_HEALTH"
  exit 0
fi

bash "$START_SCRIPT" >"$TMP_START_LOG" 2>&1 || {
  cat "$TMP_START_LOG" >&2 || true
  exit 1
}

sleep 2

if check_health >/dev/null 2>&1; then
  cat "$TMP_HEALTH"
  exit 0
fi

echo "bridge_not_ready" >&2
cat "$TMP_START_LOG" >&2 || true
exit 2
