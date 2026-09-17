#!/usr/bin/env bash
# Invoked by Codex CLI's `notify` config hook with one argument: a JSON
# payload describing the event, e.g.
#   {"type":"agent-turn-complete","last-assistant-message":"..."}
set -euo pipefail

payload="${1:-}"
message=$(printf '%s' "$payload" | jq -r '."last-assistant-message" // "Turn complete"' 2>/dev/null || echo "Turn complete")
[ -z "$message" ] && message="Turn complete"

notify-send -a "Codex" -t 2000 "Codex" "${message:0:200}" 2>/dev/null || true
