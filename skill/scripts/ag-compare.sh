#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_A="opus"
MODEL_B="gemini"
TIMEOUT=240
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model-a)
      MODEL_A="${2:?missing value for --model-a}"
      shift 2
      ;;
    --model-b)
      MODEL_B="${2:?missing value for --model-b}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:?missing value for --timeout}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage:
  ag-compare.sh [--model-a opus] [--model-b gemini] [--timeout 240] "prompt"
  printf 'prompt' | ag-compare.sh --model-a sonnet --model-b opus
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

RESP_A="$($SCRIPT_DIR/ag-chat.sh --model "$MODEL_A" --timeout "$TIMEOUT" "$PROMPT")"
RESP_B="$($SCRIPT_DIR/ag-chat.sh --model "$MODEL_B" --timeout "$TIMEOUT" "$PROMPT")"

printf '=== %s ===\n%s\n\n=== %s ===\n%s\n' "$MODEL_A" "$RESP_A" "$MODEL_B" "$RESP_B"
