# Antigravity Bridge

Turn [Antigravity](https://antigravity.com) — a free AI desktop app for macOS — into a REST API via Chrome DevTools Protocol (CDP).

## What is Antigravity?

Antigravity is a free AI desktop application for macOS that provides access to multiple AI models including:
- Claude Opus 4.6
- Claude Sonnet 4.6
- Gemini 3.1 Pro
- Gemini 3 Flash
- GPT-OSS 120B

## What does this tool do?

This bridge exposes Antigravity's AI chat capabilities as REST API endpoints, allowing you to:
- Query AI models via simple HTTP requests
- Switch between different AI models
- Trigger IDE agent tasks remotely via SSH + CDP injection

## Prerequisites

1. **Mac with Antigravity installed**
   - Download from https://antigravity.com
   
2. **Remote Login enabled on Mac**
   - System Settings → General → Sharing → Remote Login
   
3. **Python dependencies** (for Bridge API):
   ```bash
   pip install websockets
   ```

4. **Node.js with ws package** (for IDE Agent):
   ```bash
   npm install -g ws
   ```

## Quick Start

### 1. Start Antigravity with CDP debugging

```bash
# Option A: Use the startup script
bash scripts/start_antigravity.sh

# Option B: Manual start
open -a Antigravity --args --remote-debugging-port=9229
python3 scripts/bridge.py --port 19999 --cdp-port 9229
```

### 2. Use the API

```bash
# Health check
curl http://localhost:19999/health

# List available models
curl http://localhost:19999/models

# Send a chat request
curl -X POST http://localhost:19999/chat \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello, how are you?","model":"Claude Opus 4.6 (Thinking)"}'

# Switch model
curl -X POST http://localhost:19999/model \
  -H 'Content-Type: application/json' \
  -d '{"model":"Gemini 3.1 Pro (High)"}'
```

### 3. Use the CLI

```bash
# Add to PATH or use full path
export PATH="$PATH:/path/to/antigravity-bridge/scripts"

# Simple query
ag "Your question"

# Specify model
ag "Your question" opus

# With custom timeout
ag "Your question" gemini 300
```

### 4. IDE Agent Mode (remote)

```bash
# Trigger agent task on remote Mac
bash scripts/agy_invoke.sh "Fix the bug in common.sh" --model sonnet
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check, returns connection status |
| `/models` | GET | List available models |
| `/chat` | POST | Send a chat request |
| `/model` | POST | Switch current model |
| `/new` | POST | Start a new chat (clear context) |

### `/chat` Request

```json
{
  "prompt": "Your question",
  "model": "Claude Opus 4.6 (Thinking)",  // optional
  "timeout": 180                           // optional, seconds
}
```

### `/chat` Response

```json
{
  "status": "ok",
  "response": "AI response text",
  "model": "Claude Opus 4.6 (Thinking)",
  "elapsed": 5.2
}
```

## Configuration

| Parameter | Env Variable | Default | Description |
|-----------|--------------|---------|-------------|
| `--port` | `AG_BRIDGE_PORT` | 19999 | Bridge server port |
| `--cdp-port` | `AG_CDP_PORT` | 9229 | Antigravity CDP port |
| Host | `AG_BRIDGE_HOST` | localhost | Bridge server host |

## Architecture

```
┌─────────────┐         CDP (9229)         ┌─────────────────┐
│   Your App  │ ─────────────────────────►  │   Antigravity   │
│   (curl)    │                            │   (Mac)         │
└─────────────┘                            └─────────────────┘
       │
       │ HTTP (19999)
       ▼
┌─────────────┐
│  bridge.py  │  ◄── WebSocket ──► CDP
│  (Mac)      │
└─────────────┘
```

## Troubleshooting

### "No Antigravity" error
- Ensure Antigravity is running
- Check CDP port: `curl http://localhost:9229/json/list`

### "page not ready" error
- Wait for Antigravity to fully load
- Dismiss any permission dialogs

### SSH connection failed (IDE agent mode)
- Enable Remote Login on Mac
- Check firewall settings

## License

MIT License - see LICENSE file.

## Disclaimer

This tool is not affiliated with, endorsed by, or associated with Antigravity or its developers. Antigravity is a free product, and this bridge simply provides an API wrapper for its existing functionality.
