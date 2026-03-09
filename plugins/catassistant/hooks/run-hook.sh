#!/bin/sh
# run-hook.sh - Locate and run cathook binary
# Shipped with the CatAssistant Claude Code plugin.
# Buffers stdin, logs a SHIM entry to the per-session log, then dispatches to cathook.

EVENT="$1"
umask 077
LOGS_DIR="$HOME/.cat/logs"
mkdir -p "$LOGS_DIR"

# Buffer stdin so we can log before dispatching
INPUT=$(cat)

# Extract session ID and label for logging
CWD=$(echo "$INPUT" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -1)
SID=$(echo "$INPUT" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | head -1)
SID=$(echo "$SID" | tr -cd 'a-zA-Z0-9_-')
PROJECT=$(basename "$CWD")
LABEL="${PROJECT:-unknown}:$(echo "$SID" | cut -c1-8)"
LOG="$LOGS_DIR/${SID}.log"
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "$TS SHIM $EVENT $LABEL dispatching" >> "$LOG" 2>/dev/null

if [ -x "$HOME/.cat/bin/cathook" ]; then
    echo "$INPUT" | "$HOME/.cat/bin/cathook" "$EVENT"
elif [ -x "/Applications/CatAssistant.app/Contents/MacOS/cathook" ]; then
    echo "$INPUT" | /Applications/CatAssistant.app/Contents/MacOS/cathook "$EVENT"
elif [ -x "$HOME/Applications/CatAssistant.app/Contents/MacOS/cathook" ]; then
    echo "$INPUT" | "$HOME/Applications/CatAssistant.app/Contents/MacOS/cathook" "$EVENT"
else
    echo "$TS ERROR run-hook.sh: cathook not found ($LABEL event=$EVENT)" >> "$LOG" 2>/dev/null
fi
