#!/bin/bash
# Exercise claude-sync's MCP merge against a throwaway repo copy and a fake
# $HOME — never the real contexts. Checks the OAuth-only datadog and boards
# servers reach every context, personal and exxo-personal included, and that
# the shared fragment carries no credential fields. Then the parity pieces:
# the per-project disabled-flag reset (managed names only, connector and
# hand-added entries kept, exxo-openrouter untouched) and --check (exit 1 on
# drift, 0 at parity, nothing from the file's values printed).
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

# --- parity: per-project disabled flags and --check ---------------------------
# A second fake HOME, seeded before any sync: personal has a project that
# disables a managed server (playwright), a hand-added one (Foo) and a
# connector; exxo-openrouter holds the same seed and must stay byte-identical.
P="$T/parity"
for c in personal reserve exxo exxo-personal exxo-openrouter; do mkdir -p "$P/.claude-$c"; done
seed() {
    cat >"$1" <<'JSON'
{
  "oauthAccount": {"emailAddress": "SECRETLEAK-account@example.invalid"},
  "mcpServers": {"Foo": {"type": "http", "url": "https://SECRETLEAK.example.invalid/mcp"}},
  "projects": {
    "/SECRETLEAK/project-a": {
      "disabledMcpServers": ["playwright", "Foo", "claude.ai Slack"],
      "allowedTools": [],
      "note": "SECRETLEAK-value"
    },
    "/SECRETLEAK/project-b": {"disabledMcpServers": "not-an-array"},
    "/SECRETLEAK/project-c": {"enabledMcpServers": ["computer-use"]}
  }
}
JSON
    chmod 600 "$1"
}
seed "$P/.claude-personal/.claude.json"
seed "$P/.claude-exxo-openrouter/.claude.json"
or_before="$(cksum < "$P/.claude-exxo-openrouter/.claude.json")"
psync() { HOME="$P" "$REPO/scripts/claude-sync" "$@"; }

out="$(psync --check 2>&1)"; rc=$?
check "--check exits 1 before sync" test "$rc" -eq 1
check "--check names the disabled managed server" grep -q 'disabled per project: playwright (in 1 project(s))' <<<"$out"
check "--check reports missing managed servers" grep -q 'mcpServers: drift: .*(missing)' <<<"$out"
check "--check prints no value from the file" bash -c '! grep -q SECRETLEAK <<<"$1"' _ "$out"
check "--check leaves out exxo-openrouter" bash -c '! grep -q "claude-exxo-openrouter" <<<"$1"' _ "$out"
check "--check changes nothing" test "$(cksum < "$P/.claude-exxo-openrouter/.claude.json")" = "$or_before"

out="$(psync 2>&1)"; rc=$?
check "sync exits 0" test "$rc" -eq 0
L="$P/.claude-personal/.claude.json"
check "managed playwright flag reset" \
    jq -e '.projects["/SECRETLEAK/project-a"].disabledMcpServers | index("playwright") | not' "$L"
check "hand-added Foo flag kept" \
    jq -e '.projects["/SECRETLEAK/project-a"].disabledMcpServers | index("Foo") != null' "$L"
check "connector flag kept" \
    jq -e '.projects["/SECRETLEAK/project-a"].disabledMcpServers | index("claude.ai Slack") != null' "$L"
check "other project keys kept" \
    jq -e '.projects["/SECRETLEAK/project-a"].note == "SECRETLEAK-value"' "$L"
check "non-array disabledMcpServers left alone" \
    jq -e '.projects["/SECRETLEAK/project-b"].disabledMcpServers == "not-an-array"' "$L"
check "enabledMcpServers left alone" \
    jq -e '.projects["/SECRETLEAK/project-c"].enabledMcpServers == ["computer-use"]' "$L"
check "top-level keys kept" jq -e '.oauthAccount.emailAddress | startswith("SECRETLEAK")' "$L"
check "hand-added server kept" jq -e '.mcpServers.Foo.type == "http"' "$L"
check "mode stays 600" test "$(stat -f %Lp "$L" 2>/dev/null || stat -c %a "$L")" = 600
check "sync prints the reset line" grep -q 'reset per-project disabled flags in 1 project(s) for: playwright' <<<"$out"
check "sync prints no value from the file" bash -c '! grep -q SECRETLEAK <<<"$1"' _ "$out"
# exxo-openrouter still gets the pre-existing mcpServers/prefs merge; only the
# disabled-flag reset must never reach it.
check "exxo-openrouter disabled flags untouched" \
    jq -e '.projects["/SECRETLEAK/project-a"].disabledMcpServers == ["playwright", "Foo", "claude.ai Slack"]' \
    "$P/.claude-exxo-openrouter/.claude.json"

out="$(psync --check 2>&1)"; rc=$?
check "--check exits 0 after sync" test "$rc" -eq 0
check "--check prints no value after sync" bash -c '! grep -q SECRETLEAK <<<"$1"' _ "$out"

out="$(psync 2>&1)"
check "second sync is a no-op for flags" grep -q 'no project disables a managed MCP server' <<<"$out"

exit "$fail"
