#!/bin/bash
# Tests for `testlock --status` / `status` / `--help` (src/bin/testlock) under a temp
# TESTLOCK_DIR: no lock held; a fake holder owner file; live and dead waiter entries; --json;
# --help prints usage without running a command. A command string (with a fake secret) written
# into the owner file must never appear in any output. Live pids come from background sleeps;
# no process listing is used.
# Usage: bash tests/testlock-status.sh
set -uo pipefail
# shellcheck disable=SC2015,SC2329  # `check && ok || bad` is the house idiom; cleanup runs via trap

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TL="$SRC_REPO/src/bin/testlock"
T="$(cd "$(mktemp -d)" && pwd -P)"
pids=""
cleanup() { for p in $pids; do kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT
export TESTLOCK_DIR="$T/lock.d" TESTLOCK_MAX_LOAD=99
fail=0
ok() { printf 'ok: %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

sleep 300 & holder=$!; pids="$pids $holder"
sleep 300 & w1=$!; pids="$pids $w1"
sleep 300 & w2=$!; pids="$pids $w2"
sleep 0 & dead=$!; wait "$dead"

out=$("$TL" --status); rc=$?
[ "$rc" -eq 0 ] && has "$out" "lock held: no" && has "$out" "waiters: 0" && has "$out" "ceiling 99" \
  && ok "free lock" || bad "free lock: rc=$rc out=$out"

SECRET="SECRET_TOKEN_abc123"
mkdir -p "$TESTLOCK_DIR" "$TESTLOCK_DIR.waiters"
ts=$(date -u -v-90S +%FT%TZ 2>/dev/null || date -u -d '90 seconds ago' +%FT%TZ)
echo "$holder myproj $ts pnpm test --token $SECRET" > "$TESTLOCK_DIR/owner"
: > "$TESTLOCK_DIR.waiters/$w1"; : > "$TESTLOCK_DIR.waiters/$w2"; : > "$TESTLOCK_DIR.waiters/$dead"
: > "$TESTLOCK_DIR.waiters/$holder"

out=$("$TL" --status); rc=$?
[ "$rc" -eq 0 ] && has "$out" "lock held: yes" && has "$out" "holder: myproj (held 9" \
  && has "$out" "waiters: 2" && ok "held lock, 2 live waiters (dead and holder excluded)" \
  || bad "held lock: rc=$rc out=$out"
if has "$out" "$SECRET" || has "$out" "pnpm"; then bad "command leaked: $out"; else ok "no command in output"; fi
[ ! -e "$TESTLOCK_DIR.waiters/$dead" ] && ok "dead waiter pruned" || bad "dead waiter not pruned"

out=$("$TL" status --json)
has "$out" '"held":true' && has "$out" '"holder_label":"myproj"' && has "$out" '"waiters":2' \
  && has "$out" '"max_load":99' && ok "json" || bad "json: $out"
has "$out" "$SECRET" && bad "command leaked in json" || ok "no command in json"

[ -e "$TESTLOCK_DIR/owner" ] && ok "status left the lock alone" || bad "status removed the lock"

echo "$dead stale $ts echo hi" > "$TESTLOCK_DIR/owner"
out=$("$TL" --status)
has "$out" "lock held: no" && ok "dead holder reported as not held" || bad "dead holder: $out"

out=$("$TL" --help 2>&1); rc=$?
[ "$rc" -eq 0 ] && has "$out" "usage:" && has "$out" "--status" && ok "--help prints usage" || bad "--help: rc=$rc out=$out"
out=$("$TL" -h 2>&1); rc=$?
[ "$rc" -eq 0 ] && has "$out" "usage:" && ok "-h prints usage" || bad "-h: rc=$rc"

# A real run registers and unregisters as a waiter, and releases the lock.
rm -rf "$TESTLOCK_DIR" "$TESTLOCK_DIR.waiters"
"$TL" true 2>/dev/null; rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$TESTLOCK_DIR" ] && [ -z "$(ls -A "$TESTLOCK_DIR.waiters" 2>/dev/null)" ] \
  && ok "run cleans up lock and waiter entry" || bad "run cleanup rc=$rc"

exit "$fail"
