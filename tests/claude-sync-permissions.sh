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
exxo_deny="$(jq '(.permissions.deny // []) | length' "$C/settings.exxo.json")"
for ctx in personal exxo exxo-personal; do
    want_deny="$shared_deny"; [ "$ctx" = personal ] || want_deny=$((shared_deny + exxo_deny))
    check "$ctx keeps the whole shared allow set" \
        test "$(jq '[.permissions.allow[]] | length' "$FAKE/.claude-$ctx/settings.json")" -ge "$shared_allow"
    check "$ctx keeps the whole deny floor" \
        test "$(jq '.permissions.deny | length' "$FAKE/.claude-$ctx/settings.json")" -eq "$want_deny"
    check "$ctx keeps defaultMode" \
        test "$(jq -r '.permissions.defaultMode' "$FAKE/.claude-$ctx/settings.json")" = auto
    check "$ctx has git status grant" has "$ctx" allow 'Bash(git status:*)'
    for r in 'operator raise' 'operator set' 'operator decide' 'operator list' 'operator get' 'ack'; do
        check "$ctx has squad $r grant" has "$ctx" allow "Bash(squad $r:*)"
    done
done
for ctx in exxo exxo-personal; do
    check "$ctx gets the Exxo cloud grants" has "$ctx" allow 'Bash(agent-tooling:*)'
    check "$ctx: duplicate rule appears once" \
        test "$(jq '[.permissions.allow[] | select(. == "WebSearch")] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 1
done
for ctx in exxo exxo-personal; do
    check "$ctx: gcloud grants are enumerated read-only commands" has "$ctx" allow 'Bash(gcloud compute instances list:*)'
    check "$ctx: no middle-wildcard gcloud grants" \
        test "$(jq '[.permissions.allow[] | select(test("^Bash\\(gcloud \\*"))] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 0
    check "$ctx: agent-tooling mail send asks" has "$ctx" ask 'Bash(agent-tooling mail send*)'
    check "$ctx: wrapped agent-tooling mail send asks" has "$ctx" ask 'Bash(agent-run -- agent-tooling mail send*)'
    check "$ctx: gcloud compute ssh is denied" has "$ctx" deny 'Bash(gcloud compute ssh*)'
    check "$ctx: nested gcloud compute ssh is denied" has "$ctx" deny 'Bash(* gcloud compute ssh*)'
done
# deniedMcpServers lives only in the shared fragment, so the plain deep-merge
# must carry the whole array into every context (it silences the unauthenticated
# claude.ai-synced plugin servers).
shared_denied="$(jq '.deniedMcpServers | length' "$C/settings.shared.json")"
for ctx in personal exxo exxo-personal; do
    check "$ctx keeps all $shared_denied deniedMcpServers entries" \
        test "$(jq '.deniedMcpServers | length' "$FAKE/.claude-$ctx/settings.json")" -eq "$shared_denied"
done
check "deniedMcpServers is non-empty" test "$shared_denied" -gt 0
check "personal never gets the Exxo cloud grants" \
    test "$(jq '[.permissions.allow[] | select(test("agent-tooling|gcloud|pulumi"))] | length' "$FAKE/.claude-personal/settings.json")" -eq 0
check "personal never gets the Exxo gcloud ssh deny" \
    test "$(jq '[.permissions.deny[] | select(test("gcloud compute ssh"))] | length' "$FAKE/.claude-personal/settings.json")" -eq 0
check "personal never gets the exxo marketplace" \
    test "$(jq '.extraKnownMarketplaces | has("exxo-skills")' "$FAKE/.claude-personal/settings.json")" = false

out="$(sync --diff 2>&1)"
check "diff after apply: settings identical" test "$(grep -c '^  identical' <<<"$out")" -ge 3

[ "$fail" = 0 ] && echo "all claude-sync permissions tests passed"
exit "$fail"
