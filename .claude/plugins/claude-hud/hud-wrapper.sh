#!/bin/bash
# Wrapper: bash captures node output then echoes it.
# Fixes Node.js stdout full-buffering issue with Claude Code pipe.
output=$("/opt/homebrew/bin/node" "$HOME/.claude/plugins/claude-hud/hud-proxy.mjs")
echo "$output"
