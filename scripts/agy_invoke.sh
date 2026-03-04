#!/usr/bin/env bash
# agy_invoke.sh — Remote trigger Antigravity IDE agent via SSH + CDP
#
# Usage: bash agy_invoke.sh "Task description" [--model opus|gemini|sonnet|flash]
#
# Prerequisites:
#   1. Mac with Antigravity running (with --remote-debugging-port=9229)
#   2. SSH access enabled (System Settings → General → Sharing → Remote Login)
#   3. Node.js with `ws` package installed on Mac
#
# Configuration (env vars or ~/.remote-mac.conf):
#   MAC_SSH_HOST  — Mac SSH address (default: mac.local)
#   MAC_SSH_USER  — SSH user (default: current user)
#   MAC_SSH_PORT  — SSH port (default: 22)
#   AGY_NODE_PATH — npm global modules path (default: /usr/local/lib/node_modules)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Config ---
# 1. Save existing ENV vars so they take precedence over config file
_env_host="${MAC_SSH_HOST:-}"
_env_user="${MAC_SSH_USER:-}"
_env_port="${MAC_SSH_PORT:-}"
_env_node="${AGY_NODE_PATH:-}"

conf="${REMOTE_MAC_CONF:-$HOME/.remote-mac.conf}"
if [ -f "$conf" ]; then
    source "$conf"
fi

# 2. Apply priorities: ENV > CONFIG > DEFAULT
MAC_SSH_HOST="${_env_host:-${MAC_SSH_HOST:-mac.local}}"
MAC_SSH_USER="${_env_user:-${MAC_SSH_USER:-$(whoami)}}"
MAC_SSH_PORT="${_env_port:-${MAC_SSH_PORT:-22}}"
AGY_NODE_PATH="${_env_node:-${AGY_NODE_PATH:-/usr/local/lib/node_modules}}"

MAC_SSH="${MAC_SSH_USER}@${MAC_SSH_HOST}"
SSH_OPTS="-p ${MAC_SSH_PORT} -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

# --- Args ---
TASK="${1:?Usage: agy_invoke.sh 'Task description' [--model opus|gemini|sonnet|flash]}"
MODEL_HINT=""
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) MODEL_HINT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Prepend model instruction if specified
if [ -n "$MODEL_HINT" ]; then
    case "$MODEL_HINT" in
        opus)    MODEL_LINE="[Use model: Claude Opus 4.6 (Thinking)]" ;;
        gemini)  MODEL_LINE="[Use model: Gemini 3.1 Pro (High)]" ;;
        sonnet)  MODEL_LINE="[Use model: Claude Sonnet 4.6 (Thinking)]" ;;
        flash)   MODEL_LINE="[Use model: Gemini 3 Flash]" ;;
        gpt)     MODEL_LINE="[Use model: GPT-OSS 120B]" ;;
        *)       MODEL_LINE="[Use model: ${MODEL_HINT}]" ;;
    esac
    TASK="${MODEL_LINE}

${TASK}"
fi

echo "🚀 Antigravity invoke"
echo "   Task: ${TASK:0:100}"
[ -n "$MODEL_HINT" ] && echo "   Model: $MODEL_HINT"

# 1. Check Mac online via SSH
if ! ssh $SSH_OPTS "$MAC_SSH" "echo ok" &>/dev/null 2>&1; then
    echo "❌ SSH connection failed (host: $MAC_SSH_HOST)" >&2
    echo "   Hint: Enable Remote Login on Mac (System Settings → General → Sharing → Remote Login)" >&2
    exit 1
fi

# 2. Check Antigravity is running (workbench page must exist)
WB_COUNT=$(ssh $SSH_OPTS "$MAC_SSH" \
    "curl -s http://localhost:9229/json/list 2>/dev/null | python3 -c \"import sys,json; pages=json.load(sys.stdin); print(sum(1 for p in pages if 'workbench.html' in p.get('url','') and 'jetski' not in p.get('url','')))\" 2>/dev/null || echo 0")
if [ "${WB_COUNT:-0}" -eq 0 ]; then
    echo "❌ Antigravity workbench not open" >&2
    echo "   Please open Antigravity and ensure main window is visible" >&2
    exit 1
fi

# Determine user on Mac to avoid permission conflicts
WHOAMI_ON_MAC=$(ssh $SSH_OPTS "$MAC_SSH" "whoami" 2>/dev/null || echo "${MAC_SSH_USER}")
REMOTE_SCRIPT="/tmp/agy_inject_${WHOAMI_ON_MAC}.js"

# 3. Upload inject script (only if changed or missing)
LOCAL_HASH=$(md5sum "$SCRIPT_DIR/cdp_inject.js" 2>/dev/null | cut -d' ' -f1)
REMOTE_HASH=$(ssh $SSH_OPTS "$MAC_SSH" "md5 -q '$REMOTE_SCRIPT' 2>/dev/null || echo none")
if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
    scp -P "$MAC_SSH_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        "$SCRIPT_DIR/cdp_inject.js" "$MAC_SSH:$REMOTE_SCRIPT" >/dev/null 2>&1
fi

# 4. Detect Node.js and npm global modules on Mac
NODE_PATH_REMOTE=$(ssh $SSH_OPTS "$MAC_SSH" \
    "npm root -g 2>/dev/null || echo '${AGY_NODE_PATH}'")

# 5. Run inject script
ssh $SSH_OPTS "$MAC_SSH" \
    "export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH; \
     export NODE_PATH='${NODE_PATH_REMOTE}'; \
     export AGY_PROMPT=$(printf '%q' "$TASK"); \
     node '$REMOTE_SCRIPT'"

echo "🎯 Antigravity agent is processing"
