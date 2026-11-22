#!/bin/bash
# MCP parity in the live Gaia instance config (src/.config/squad/config.toml):
# the three Anthropic accounts (personal, reserve, exxo) provide the same
# capability list, so any of them can take any task and quota can be balanced
# freely. Builders never get Notion or Slack (Tim, 22 Nov 2026), so no account
# provides either, and the openrouter account does not claim boards, which its
# context denies.
# Usage: bash tests/squad-config-parity.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$SRC_REPO/src/.config/squad/config.toml"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

prov() { yq -p toml -oy ".accounts[] | select(.name == \"$1\") | .provides | sort | join(\" \")" "$CFG"; }

p="$(prov personal)"; r="$(prov reserve)"; e="$(prov exxo)"; o="$(prov openrouter)"
check "personal provides something" test -n "$p"
check "reserve provides the same as personal" test "$r" = "$p"
check "exxo provides the same as personal" test "$e" = "$p"
for cap in figma vercel datadog boards playwright; do
    check "the Anthropic accounts provide $cap" grep -qw "$cap" <<<"$p"
done
for a in personal reserve exxo openrouter; do
    check "$a provides neither notion nor slack" bash -c '! grep -qwE "notion|slack" <<<"$1"' _ "$(prov "$a")"
done
check "openrouter does not provide boards (its context denies it)" bash -c '! grep -qw boards <<<"$1"' _ "$o"
check "needs_mcp maps no notion or slack server" \
    bash -c '! yq -p toml -oy ".policy.launch.needs_mcp | keys | .[]" "$1" | grep -qwE "notion|slack"' _ "$CFG"

[ "$fail" = 0 ] && echo "all squad config parity tests passed"
exit "$fail"
