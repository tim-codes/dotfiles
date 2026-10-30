#!/bin/bash
# Exercise claude-sync's MCP merge against a throwaway repo copy and a fake
# $HOME — never the real contexts. Checks the OAuth-only datadog and boards
# servers reach every context, personal and exxo-personal included, and that
# the shared fragment carries no credential fields.
# Usage: bash tests/claude-sync-mcp.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal reserve exxo exxo-personal; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null; then ok "$d"; else bad "$d"; fi; }

HOME="$FAKE" "$REPO/scripts/claude-sync" >/dev/null 2>&1
for c in personal reserve exxo exxo-personal; do
    for s in datadog boards; do
        check "$c merged MCP includes $s" \
            jq -e --arg s "$s" '.mcpServers[$s].type == "http"' "$FAKE/.claude-$c/.claude.json"
    done
done
check "datadog/boards in shared fragment are credential-free" \
    jq -e '[.mcpServers.datadog, .mcpServers.boards] | all(keys - ["type","url"] | length == 0)' \
    "$SRC_REPO/files/claude/mcp.shared.json"
check "mcp.exxo.json no longer defines them" \
    test ! -e "$SRC_REPO/files/claude/mcp.exxo.json"

exit "$fail"
