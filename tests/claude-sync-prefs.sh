#!/bin/bash
# Exercise claude-sync's managed-preferences merge (files/claude/prefs.*.json
# into <context>/.claude.json) against a throwaway repo copy and a fake $HOME —
# never the real contexts. Checks the keys merge, unrelated keys (oauthAccount,
# projects) survive, a re-run is a no-op, --diff prints key names and never
# values, a missing file is seeded, the mode is preserved, and the exxo contexts
# get only the keys in prefs.exxo.json (oauth and counters untouched).
# Usage: bash tests/claude-sync-prefs.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal reserve exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }

P="$FAKE/.claude-personal"; X="$FAKE/.claude-exxo"
# Personal: one managed key already current, one differing, the rest missing,
# plus unrelated keys that must survive.
cat > "$P/.claude.json" <<'JSON'
{"oauthAccount":{"emailAddress":"sentinel-account"},"projects":{"/x":{"allowedTools":[]}},
 "numStartups":42,"deepLinkTerminal":"sentinel-differs","diffSidebarOpen":false}
JSON
chmod 640 "$P/.claude.json"
printf '{"oauthAccount":{"emailAddress":"sentinel-exxo"},"numStartups":7}\n' > "$X/.claude.json"
cp "$X/.claude.json" "$T/exxo.orig"

out="$(sync --diff 2>&1)"
check "diff: current key listed" grep -qF 'diffSidebarOpen: current' <<<"$out"
check "diff: differing key listed" grep -qF 'deepLinkTerminal: differs (would be reset)' <<<"$out"
check "diff: missing key listed" grep -qF 'effortCalloutDismissed: missing (would be added)' <<<"$out"
check "diff: no values printed" bash -c '! grep -qE "sentinel|iTerm" <<<"$1"' _ "$out"
check "diff: exxo lists its own preferences section" \
    grep -q "exxo/.claude.json preferences" <<<"$out"
check "diff changed nothing" bash -c '! jq -e has\(\"effortCalloutDismissed\"\) "$1"' _ "$P/.claude.json"

sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }
for c in personal reserve; do
    f="$FAKE/.claude-$c/.claude.json"
    check "$c: every managed key merged" \
        jq -e --slurpfile m "$SRC_REPO/files/claude/prefs.personal.json" '. as $d | $m[0] | to_entries | all($d[.key] == .value)' "$f"
done
check "personal: oauthAccount preserved" jq -e '.oauthAccount.emailAddress == "sentinel-account"' "$P/.claude.json"
check "personal: projects preserved" jq -e '.projects["/x"].allowedTools == []' "$P/.claude.json"
check "personal: counter preserved" jq -e '.numStartups == 42' "$P/.claude.json"
check "personal: managed value reset" jq -e '.deepLinkTerminal == "iTerm"' "$P/.claude.json"
check "personal: file mode preserved" test "$(stat -f %Lp "$P/.claude.json" 2>/dev/null || stat -c %a "$P/.claude.json")" = 640
check "reserve: seeded file is mode 600" test "$(stat -f %Lp "$FAKE/.claude-reserve/.claude.json" 2>/dev/null || stat -c %a "$FAKE/.claude-reserve/.claude.json")" = 600
check "apply output prints no values" bash -c '! grep -qE "sentinel|iTerm" "$1"' _ "$T/apply.log"
check "exxo .claude.json carries no managed pref" bash -c '! jq -e has\(\"deepLinkTerminal\"\) "$1"' _ "$X/.claude.json"
check "exxo-personal gets no managed pref" bash -c '! jq -e has\(\"deepLinkTerminal\"\) "$1"' _ "$FAKE/.claude-exxo-personal/.claude.json"
for c in exxo exxo-personal; do
    check "$c: gets the exxo-fragment Chrome pref" \
        jq -e --slurpfile m "$SRC_REPO/files/claude/prefs.exxo.json" '. as $d | $m[0] | to_entries | all($d[.key] == .value)' "$FAKE/.claude-$c/.claude.json"
done
check "exxo oauth and counter untouched" \
    jq -e '.oauthAccount.emailAddress == "sentinel-exxo" and .numStartups == 7' "$X/.claude.json"

cp "$P/.claude.json" "$T/personal.after"
touch -r "$P/.claude.json" "$T/stamp"
sync >"$T/again.log" 2>&1
check "re-run reports preferences already current" grep -q 'preferences already current' "$T/again.log"
check "re-run is a no-op (bytes identical)" cmp -s "$P/.claude.json" "$T/personal.after"

exit "$fail"
