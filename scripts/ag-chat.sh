#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE_URL="${AG_BRIDGE_HOST:-http://127.0.0.1:19999}"
MODEL="opus"
TIMEOUT=180
KEEP_CONTEXT=0
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="${2:?missing value for --model}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:?missing value for --timeout}"
      shift 2
      ;;
    --keep-context)
      KEEP_CONTEXT=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage:
  ag-chat.sh [--model opus] [--timeout 180] [--keep-context] "prompt"
  printf 'prompt' | ag-chat.sh --model gemini
EOF
      exit 0
      ;;
    *)
      if [[ -n "$PROMPT" ]]; then
        PROMPT+=$' '
        PROMPT+="$1"
      else
        PROMPT="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROMPT" && ! -t 0 ]]; then
  PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
  echo "ERROR: prompt is required" >&2
  exit 1
fi

"$SCRIPT_DIR/ensure-bridge.sh" >/dev/null

if [[ "$KEEP_CONTEXT" != "1" ]]; then
  curl -fsS -X POST "$BRIDGE_URL/new" -H 'Content-Type: application/json' -d '{}' >/dev/null
fi

AG_BRIDGE_HOST="$BRIDGE_URL" "$REPO_DIR/scripts/ag_chat.sh" "$PROMPT" "$MODEL" "$TIMEOUT"
