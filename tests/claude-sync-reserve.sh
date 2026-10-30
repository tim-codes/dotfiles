#!/bin/bash
# Exercise claude-sync's `reserve` context (a second personal-account context
# with fully separate durable state) against a throwaway repo copy and a fake
# $HOME — never the real contexts. Checks it is built from the personal
# fragments, gets the whole-directory skills/agents symlinks keyed on the
# fragment account, receives merged MCP servers, gets NO overlay symlinks,
# and that exxo-personal / exxo-openrouter behaviour is unchanged.
# Usage: bash tests/claude-sync-reserve.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal reserve exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done
F="$REPO/files/claude"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }

# --- diff names the whole-dir link for reserve and is read-only ---
out="$(sync --diff 2>&1)"
check "diff: reserve section present" grep -q '~/.claude-reserve' <<<"$out"
check "diff is read-only (no reserve agents/skills)" \
    test ! -e "$FAKE/.claude-reserve/agents" -a ! -e "$FAKE/.claude-reserve/skills"

# --- apply ---
sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }
R="$FAKE/.claude-reserve"; P="$FAKE/.claude-personal"

check "reserve settings.json equals personal's" cmp -s "$R/settings.json" "$P/settings.json"
check "reserve settings carry no exxo marketplace" \
    jq -e '(.extraKnownMarketplaces // {}) | has("exxo-skills") | not' "$R/settings.json"
check "reserve CLAUDE.md equals personal's" cmp -s "$R/CLAUDE.md" "$P/CLAUDE.md"
check "reserve CLAUDE.md differs from exxo's" bash -c '! cmp -s "$1" "$2"' _ "$R/CLAUDE.md" "$FAKE/.claude-exxo/CLAUDE.md"

check "reserve skills is a whole-dir symlink to the repo" test "$(readlink "$R/skills")" = "$F/skills"
check "reserve agents is a whole-dir symlink to the repo" test "$(readlink "$R/agents")" = "$F/agents"
check "reserve sees a personal-only skill" test -e "$R/skills/run-with-secrets/SKILL.md"
check "reserve skills match personal's target" test "$(readlink "$R/skills")" = "$(readlink "$P/skills")"

for s in datadog boards; do
    check "reserve merged MCP includes $s" jq -e --arg s "$s" '.mcpServers[$s].type == "http"' "$R/.claude.json"
done
check "reserve MCP equals personal's" \
    test "$(jq -S .mcpServers "$R/.claude.json")" = "$(jq -S .mcpServers "$P/.claude.json")"

# no overlay: nothing in reserve may be a symlink except skills/agents
links="$(find "$R" -maxdepth 1 -type l -exec basename {} \; | sort | tr '\n' ' ')"
check "reserve links are exactly agents+skills (got: $links)" test "$links" = "agents skills "
for d in projects plugins file-history plans tasks todos paste-cache history.jsonl; do
    check "reserve/$d is not a symlink" test ! -L "$R/$d"
done

# --- idempotent ---
sync >"$T/apply2.log" 2>&1
check "second run: reserve agents already linked" grep -q 'agents: already linked' "$T/apply2.log"

# --- unchanged behaviour of the exxo contexts ---
for ctx in exxo exxo-personal exxo-openrouter; do
    d="$FAKE/.claude-$ctx"
    check "$ctx agents is a real dir" test -d "$d/agents" -a ! -L "$d/agents"
    check "$ctx skills is a real dir (curated)" test -d "$d/skills" -a ! -L "$d/skills"
    check "$ctx has no personal-only skill" test ! -e "$d/skills/run-with-secrets"
    check "$ctx settings carry exxo marketplace" jq -e '.extraKnownMarketplaces | has("exxo-skills")' "$d/settings.json"
done
check "exxo-personal projects links into exxo" test "$(readlink "$FAKE/.claude-exxo-personal/projects")" = "$FAKE/.claude-exxo/projects"
check "exxo-openrouter plugins links into exxo" test "$(readlink "$FAKE/.claude-exxo-openrouter/plugins")" = "$FAKE/.claude-exxo/plugins"
check "exxo-openrouter projects is not linked" test ! -L "$FAKE/.claude-exxo-openrouter/projects"
check "personal skills still whole-dir" test "$(readlink "$P/skills")" = "$F/skills"

[ "$fail" = 0 ] && echo "all claude-sync reserve tests passed"
exit "$fail"
