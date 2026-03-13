#!/bin/sh
# run-hook.sh - Locate and run nekode binary with --source copilot-cli
# Shipped with the Nekode Copilot CLI plugin.
# Buffers stdin, logs a SHIM entry to the per-session log, then dispatches to nekode hook.

EVENT="$1"
umask 077
LOGS_DIR="$HOME/.nekode/logs"
mkdir -p "$LOGS_DIR"

# Buffer stdin so we can log before dispatching
INPUT=$(cat)

# Extract session ID — Copilot CLI uses camelCase "sessionId"
CWD=$(echo "$INPUT" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -1)
SID=$(echo "$INPUT" | sed -n 's/.*"sessionId" *: *"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$SID" ]; then
    SID=$(echo "$INPUT" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | head -1)
fi
SID=$(echo "$SID" | tr -cd 'a-zA-Z0-9_-')
PROJECT=$(basename "$CWD")
LABEL="${PROJECT:-unknown}:$(echo "$SID" | cut -c1-8)"
LOG="$LOGS_DIR/${SID}.log"
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "$TS SHIM(copilot-cli) $EVENT $LABEL dispatching" >> "$LOG" 2>/dev/null

if [ -x "$HOME/.nekode/bin/nekode" ]; then
    echo "$INPUT" | "$HOME/.nekode/bin/nekode" hook --source copilot-cli "$EVENT"
elif [ -x "/Applications/Nekode.app/Contents/MacOS/nekode" ]; then
    echo "$INPUT" | /Applications/Nekode.app/Contents/MacOS/nekode hook --source copilot-cli "$EVENT"
elif [ -x "$HOME/Applications/Nekode.app/Contents/MacOS/nekode" ]; then
    echo "$INPUT" | "$HOME/Applications/Nekode.app/Contents/MacOS/nekode" hook --source copilot-cli "$EVENT"
else
    echo "$TS ERROR run-hook.sh: nekode not found ($LABEL event=$EVENT)" >> "$LOG" 2>/dev/null
fi
