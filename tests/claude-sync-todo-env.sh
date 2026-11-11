#!/bin/bash
# Assert CLAUDE_CODE_ENABLE_TODO_TOOLS=1 lands in every context claude-sync
# builds (incl. exxo-openrouter, whose overlay has its own env block, which must
# merge with, not replace, the shared one), and that every context's CLAUDE.md
# comes from the shared fragment carrying the task-tracking import.
# Throwaway repo copy + fake $HOME, like claude-sync-openrouter.sh.
# Usage: bash tests/claude-sync-todo-env.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
CTXS=(personal reserve exxo exxo-personal exxo-openrouter)
for c in "${CTXS[@]}"; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

# Every context claude-sync knows about must be covered here.
declared="$(sed -n 's/^CONTEXTS=(\(.*\))$/\1/p' "$SRC_REPO/scripts/claude-sync" | tr -d '"' | tr ' ' '\n' | cut -d: -f1 | sort | tr '\n' ' ')"
expected="$(printf '%s\n' "${CTXS[@]}" | sort | tr '\n' ' ')"
[ "$declared" = "$expected" ] && ok "test covers every claude-sync context" || bad "claude-sync contexts ($declared) differ from test list ($expected)"

HOME="$FAKE" "$REPO/scripts/claude-sync" >"$T/apply.log" 2>&1 || { bad "claude-sync exited non-zero"; cat "$T/apply.log"; }

for c in "${CTXS[@]}"; do
    v="$(jq -r '.env.CLAUDE_CODE_ENABLE_TODO_TOOLS' "$FAKE/.claude-$c/settings.json" 2>/dev/null)"
    [ "$v" = "1" ] && ok "$c: env.CLAUDE_CODE_ENABLE_TODO_TOOLS == 1" || bad "$c: flag is '$v'"
    grep -q 'agent-conventions/task-tracking.md' "$FAKE/.claude-$c/CLAUDE.md" 2>/dev/null \
        && ok "$c: CLAUDE.md imports task-tracking convention" || bad "$c: CLAUDE.md lacks task-tracking import"
done
# The overlay's own env keys survive alongside the flag.
[ "$(jq -r '.env.ENABLE_TOOL_SEARCH' "$FAKE/.claude-exxo-openrouter/settings.json")" = "false" ] \
    && ok "exxo-openrouter: overlay env keys preserved" || bad "exxo-openrouter: overlay env lost"

[ $fail -eq 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
