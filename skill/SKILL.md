---
name: antigravity-bridge
description: Use the local Antigravity Bridge as a low-cost sidecar model channel for second opinions, bug analysis, prompt comparisons, or quick Q&A with Antigravity desktop models such as Opus, Gemini, and Sonnet. Use when the user explicitly asks for antigravity/bridge/free Opus/free Gemini, wants a model comparison through the local Antigravity desktop app, or wants Antigravity analysis before the main coding path.
---

# Antigravity Bridge

Use Antigravity Bridge as an auxiliary local model path, not the primary coding harness.

## Default role

- Use it for second opinions, bug diagnosis, summaries, prompt rewrites, and model comparisons.
- Do **not** use it as the main multi-file coding path when `tmux + acpx` or explicit ACP is the better fit.
- Treat each call as fragile UI automation behind a local HTTP bridge.

## Workflow

1. Ensure the local bridge is running:
   - Run `scripts/ensure-bridge.sh`
2. For a single prompt:
   - Run `scripts/ag-chat.sh --model opus "Explain this error"`
3. To clear context:
   - Run `scripts/ag-reset.sh`
4. To compare two models:
   - Run `scripts/ag-compare.sh --model-a opus --model-b gemini "Analyze this bug"`
5. Return the result in normal assistant voice

## Paths

- Workspace entry symlink: `/Users/iaos/.openclaw/workspace/skills/antigravity-bridge`
- Canonical skill dir (repo-managed): `/Users/iaos/.openclaw/workspace/tools/antigravity-bridge/skill`
- Bridge repo: `/Users/iaos/.openclaw/workspace/tools/antigravity-bridge`
- Bridge URL default: `http://127.0.0.1:19999`

## Operating rules

1. Run `ensure-bridge.sh` before first use.
2. Default to a fresh conversation unless the task explicitly needs follow-up context.
3. Keep requests serialized and moderate in frequency.
4. Treat results as advisory; if code changes are needed, route the implementation back to the normal coding path.
5. Bridge listens on localhost only in this workspace setup.

## Model aliases

- `opus` → `Claude Opus 4.6 (Thinking)`
- `gemini` → `Gemini 3.1 Pro (High)`
- `gemini-low` → `Gemini 3.1 Pro (Low)`
- `sonnet` → `Claude Sonnet 4.6 (Thinking)`
- `flash` → `Gemini 3 Flash`
- `gpt` → `GPT-OSS 120B (Medium)`

## Risk

This path depends on CDP automation of the Antigravity desktop client and is likely detectable by the upstream service. Prefer a throwaway account and do not treat it as production infrastructure.
