#!/bin/bash
# Exercise claude-sync's settings merge against a throwaway repo copy and a
# fake $HOME — never the real contexts (same isolation as
# claude-sync-agents.sh). Checks that permission rule arrays from the shared
# and account fragments are concatenated rather than replaced, and that the
# personal context never receives the Exxo grants.
# Usage: bash tests/claude-sync-permissions.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal exxo exxo-personal; do mkdir -p "$FAKE/.claude-$c"; done
C="$REPO/files/claude"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }
has() { jq -e --arg r "$3" ".permissions.$2 | index([\$r]) != null" "$FAKE/.claude-$1/settings.json" >/dev/null; }

# A shared rule duplicated in the account fragment must appear once.
jq '.permissions.allow += ["WebSearch"]' "$C/settings.exxo.json" > "$T/x" && mv "$T/x" "$C/settings.exxo.json"

sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }

shared_allow="$(jq '.permissions.allow | length' "$C/settings.shared.json")"
shared_deny="$(jq '.permissions.deny | length' "$C/settings.shared.json")"
for ctx in personal exxo exxo-personal; do
    check "$ctx keeps the whole shared allow set" \
        test "$(jq '[.permissions.allow[]] | length' "$FAKE/.claude-$ctx/settings.json")" -ge "$shared_allow"
    check "$ctx keeps the whole deny floor" \
        test "$(jq '.permissions.deny | length' "$FAKE/.claude-$ctx/settings.json")" -eq "$shared_deny"
    check "$ctx keeps defaultMode" \
        test "$(jq -r '.permissions.defaultMode' "$FAKE/.claude-$ctx/settings.json")" = auto
    check "$ctx has git status grant" has "$ctx" allow 'Bash(git status:*)'
done
for ctx in exxo exxo-personal; do
    check "$ctx gets the Exxo cloud grants" has "$ctx" allow 'Bash(agent-tooling:*)'
    check "$ctx: duplicate rule appears once" \
        test "$(jq '[.permissions.allow[] | select(. == "WebSearch")] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 1
done
check "personal never gets the Exxo cloud grants" \
    test "$(jq '[.permissions.allow[] | select(test("agent-tooling|gcloud|pulumi"))] | length' "$FAKE/.claude-personal/settings.json")" -eq 0
check "personal never gets the exxo marketplace" \
    test "$(jq '.extraKnownMarketplaces | has("exxo-skills")' "$FAKE/.claude-personal/settings.json")" = false

out="$(sync --diff 2>&1)"
check "diff after apply: settings identical" test "$(grep -c '^  identical' <<<"$out")" -ge 3

[ "$fail" = 0 ] && echo "all claude-sync permissions tests passed"
exit "$fail"
