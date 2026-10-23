#!/bin/bash
# Exercise claude-sync's argument handling against a throwaway repo copy and a
# fake $HOME — never the real contexts (same isolation as
# claude-sync-agents.sh). --help must exit 0 and touch nothing; an unknown
# argument must exit 2 and touch nothing (it used to fall through to a real
# sync); --diff must still work and change nothing.
# Usage: bash tests/claude-sync-args.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal exxo exxo-personal; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }
snapshot() { (cd "$FAKE" && find . | LC_ALL=C sort); }

before="$(snapshot)"

out="$(sync --help 2>&1)"; rc=$?
check "--help exits 0" test "$rc" -eq 0
check "--help prints usage" grep -q '^Usage: claude-sync' <<<"$out"
check "--help touches nothing" test "$(snapshot)" = "$before"

out="$(sync -h 2>&1)"; rc=$?
check "-h exits 0" test "$rc" -eq 0
check "-h touches nothing" test "$(snapshot)" = "$before"

out="$(sync --bogus 2>&1)"; rc=$?
check "--bogus exits 2" test "$rc" -eq 2
check "--bogus prints usage" grep -q '^Usage: claude-sync' <<<"$out"
check "--bogus touches nothing" test "$(snapshot)" = "$before"

out="$(sync --diff --bogus 2>&1)"; rc=$?
check "extra argument after --diff exits 2" test "$rc" -eq 2
check "extra argument after --diff touches nothing" test "$(snapshot)" = "$before"

out="$(sync --diff 2>&1)"; rc=$?
check "--diff exits 0" test "$rc" -eq 0
check "--diff reports each context" test "$(grep -c 'vs repo (settings.shared.json' <<<"$out")" -eq 3
check "--diff changes nothing" test "$(snapshot)" = "$before"

sync >"$T/apply.log" 2>&1; rc=$?
check "no argument still applies" test "$rc" -eq 0
check "no argument writes settings" test -f "$FAKE/.claude-personal/settings.json"

[ "$fail" = 0 ] && echo "all claude-sync args tests passed"
exit "$fail"
