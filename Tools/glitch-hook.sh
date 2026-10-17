#!/bin/sh
# Claude Code hook for Glitch: drops the event (stdin) into Glitch's spool folder and returns at once.
# temp + rename so Glitch never reads a half-written file; always exits 0 so Claude Code is never affected.
d="$HOME/Library/Application Support/Glitch/events"
mkdir -p "$d" 2>/dev/null
f="$d/$(date +%s).$$"
cat > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f.json" 2>/dev/null
exit 0
