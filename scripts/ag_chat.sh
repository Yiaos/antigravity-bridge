#!/bin/bash
# ag_chat.sh — Antigravity Bridge CLI
# Usage: ag "Your question" [opus|gemini|sonnet|flash|gpt] [timeout]
# Returns: plain text response
# Auto-retry on high traffic (max 3 times, 15s interval)

BRIDGE="${AG_BRIDGE_HOST:-http://localhost:19999}"
PROMPT="${1:?Usage: ag \"question\" [model] [timeout]}"
MODEL_SHORT="${2:-opus}"
TIMEOUT="${3:-180}"
MAX_RETRY=3

case "$MODEL_SHORT" in
  opus)      MODEL="Claude Opus 4.6 (Thinking)" ;;
  sonnet)    MODEL="Claude Sonnet 4.6 (Thinking)" ;;
  gemini)    MODEL="Gemini 3.1 Pro (High)" ;;
  gemini-low) MODEL="Gemini 3.1 Pro (Low)" ;;
  flash)     MODEL="Gemini 3 Flash" ;;
  gpt)       MODEL="GPT-OSS 120B (Medium)" ;;
  *)         MODEL="$MODEL_SHORT" ;;
esac

if ! curl -s -m 3 "$BRIDGE/health" | grep -q '"ok"'; then
  echo "ERROR: Antigravity Bridge offline" >&2
  exit 1
fi

PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'prompt':sys.argv[1],'model':sys.argv[2],'timeout':int(sys.argv[3])}))" "$PROMPT" "$MODEL" "$TIMEOUT")

for i in $(seq 1 $MAX_RETRY); do
  RESULT=$(curl -s -m $((TIMEOUT + 60)) -X POST "$BRIDGE/chat" \
    -H 'Content-Type: application/json' -d "$PAYLOAD" 2>&1)

  STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','error'))" 2>/dev/null || echo "error")
  RESPONSE=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "")

  if [ "$STATUS" = "ok" ]; then
    echo "$RESPONSE"
    exit 0
  elif [ "$STATUS" = "high_traffic" ]; then
    if [ $i -lt $MAX_RETRY ]; then
      echo "High traffic, retry $i/$MAX_RETRY in 15s..." >&2
      sleep 15
    else
      echo "ERROR: High traffic after $MAX_RETRY retries" >&2
      exit 2
    fi
  else
    echo "ERROR: $RESULT" >&2
    exit 1
  fi
done
