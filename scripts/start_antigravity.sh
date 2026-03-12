#!/usr/bin/env bash
set -euo pipefail

# start_antigravity.sh — Start Antigravity with CDP debug port and localhost-only bridge server

CDP_PORT="${AG_CDP_PORT:-9229}"
BRIDGE_PORT="${AG_BRIDGE_PORT:-19999}"
BRIDGE_HOST="${AG_BRIDGE_BIND_HOST:-127.0.0.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$REPO_DIR/.venv"
LOG_FILE="${AG_BRIDGE_LOG:-/tmp/ag_bridge.log}"
PYTHON_BIN="$VENV_DIR/bin/python3"

ensure_python_env() {
  if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "Creating Python venv in $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
  fi

  if ! "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util
raise SystemExit(0 if importlib.util.find_spec('websockets') else 1)
PY
  then
    echo "Installing Python dependency: websockets"
    "$PYTHON_BIN" -m pip install websockets >/dev/null
  fi
}

# Stop previous bridge instance only.
pkill -f "bridge.py.*--port ${BRIDGE_PORT}" 2>/dev/null || true
pkill -f "bridge.py --host ${BRIDGE_HOST} --port ${BRIDGE_PORT}" 2>/dev/null || true

# Check if Antigravity is already exposing CDP.
if ! curl -fsS "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1; then
  echo "Starting Antigravity with --remote-debugging-port=${CDP_PORT} ..."
  osascript -e 'tell application "Antigravity" to quit' >/dev/null 2>&1 || true
  sleep 2
  open -a Antigravity --args --remote-debugging-port="$CDP_PORT"
  sleep 6

  if ! curl -fsS "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1; then
    echo "❌ Failed to start Antigravity with CDP on port ${CDP_PORT}" >&2
    exit 1
  fi
  echo "✅ Antigravity started with CDP on port ${CDP_PORT}"
else
  echo "✅ Antigravity already running with CDP on port ${CDP_PORT}"
fi

ensure_python_env

echo "Starting bridge on ${BRIDGE_HOST}:${BRIDGE_PORT} ..."
nohup "$PYTHON_BIN" "$SCRIPT_DIR/bridge.py" --host "$BRIDGE_HOST" --port "$BRIDGE_PORT" --cdp-port "$CDP_PORT" \
  >"$LOG_FILE" 2>&1 &
echo "Bridge PID: $!"

sleep 2
if curl -fsS "http://${BRIDGE_HOST}:${BRIDGE_PORT}/health" >/dev/null 2>&1; then
  echo "✅ Bridge healthy on ${BRIDGE_HOST}:${BRIDGE_PORT}"
  echo "Usage:"
  echo "  curl http://${BRIDGE_HOST}:${BRIDGE_PORT}/models"
  echo "  bash $REPO_DIR/scripts/ag_chat.sh \"hello\" opus"
else
  echo "❌ Bridge failed to start" >&2
  cat "$LOG_FILE" >&2 || true
  exit 1
fi
