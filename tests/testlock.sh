#!/bin/bash
# Exercise src/bin/testlock with a temp lock dir and a stubbed `sysctl` on PATH — never the
# real lock or the real load average. Covers serialisation, stale-lock reclaim, the load
# ceiling, exit-code pass-through and the timeout kill.
# Usage: bash tests/testlock.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TL="$SRC_REPO/src/bin/testlock"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; mkdir -p "$BIN"
export TESTLOCK_DIR="$T/lock.d" TESTLOCK_POLL_S=1 TESTLOCK_LOAD_POLL_S=1 TESTLOCK_LABEL=t
export LOADFILE="$T/load"; echo 0 > "$LOADFILE"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
stub() { printf '#!/bin/bash\n%s\n' "$2" >"$BIN/$1"; chmod +x "$BIN/$1"; }

# sysctl -n vm.loadavg -> "{ <load> 1.0 1.0 }", the load read from $LOADFILE
stub sysctl 'echo "{ $(cat "$LOADFILE").00 1.00 1.00 }"'
export PATH="$BIN:$PATH"

# 1. exit code passes through
"$TL" bash -c 'exit 7' 2>/dev/null; rc=$?
check "exit code passes through (7)" test "$rc" = 7
check "lock released afterwards" test ! -e "$TESTLOCK_DIR"

# 2. two concurrent invocations serialise: intervals must not overlap
ev="$T/events"; : > "$ev"
job='echo "start $1 $(date +%s)" >>'"$ev"'; sleep 2; echo "end $1 $(date +%s)" >>'"$ev"
"$TL" bash -c "$job" _ A 2>/dev/null &
sleep 0.5
"$TL" bash -c "$job" _ B 2>/dev/null &
wait
sa=$(awk '$2=="A"&&$1=="start"{print $3}' "$ev"); ea=$(awk '$2=="A"&&$1=="end"{print $3}' "$ev")
sb=$(awk '$2=="B"&&$1=="start"{print $3}' "$ev"); eb=$(awk '$2=="B"&&$1=="end"{print $3}' "$ev")
if [ -n "$sa" ] && [ -n "$sb" ] && { [ "$sb" -ge "$ea" ] || [ "$sa" -ge "$eb" ]; }; then
  ok "two concurrent invocations serialise"
else bad "two concurrent invocations serialise ($(tr '\n' ';' <"$ev"))"; fi

# 3. a stale lock from a dead pid is reclaimed
sleep 0 & dead=$!; wait "$dead"
mkdir -p "$TESTLOCK_DIR"; echo "$dead old $(date -u +%FT%TZ) x" >"$TESTLOCK_DIR/owner"
out=$("$TL" echo reclaimed 2>&1); rc=$?
check "stale lock reclaimed and command ran" test "$rc" = 0 -a "$(printf '%s' "$out" | grep -c '^reclaimed$')" = 1
check "stale reclaim is announced" bash -c "printf '%s' \"\$1\" | grep -q 'stale lock'" _ "$out"

# 4. a live lock is waited on (and named), not stolen
mkdir -p "$TESTLOCK_DIR"; echo "$$ holder $(date -u +%FT%TZ) busy-thing" >"$TESTLOCK_DIR/owner"
( sleep 2; rm -rf "$TESTLOCK_DIR" ) &
out=$("$TL" echo got 2>&1); rc=$?
check "waits on a live lock and names the holder" bash -c "printf '%s' \"\$1\" | grep -q 'holder.*busy-thing'" _ "$out"
check "runs once the lock is freed" test "$rc" = 0
wait

# 5. TESTLOCK_MAX_LOAD with a stubbed sysctl: waits while load >= ceiling, then proceeds
echo 30 > "$LOADFILE"
( sleep 2; echo 3 > "$LOADFILE" ) &
out=$(TESTLOCK_MAX_LOAD=10 "$TL" echo ran 2>&1); rc=$?
wait
check "waits while load is over the ceiling" bash -c "printf '%s' \"\$1\" | grep -q 'load 30 >= 10'" _ "$out"
check "proceeds once load drops" test "$rc" = 0 -a "$(printf '%s' "$out" | grep -c '^ran$')" = 1
echo 0 > "$LOADFILE"

# 6. timeout kills a hung command (needs timeout or gtimeout)
if command -v timeout >/dev/null || command -v gtimeout >/dev/null; then
  start=$(date +%s)
  TESTLOCK_TIMEOUT_S=1 "$TL" sleep 30 2>/dev/null; rc=$?
  el=$(( $(date +%s) - start ))
  check "timeout kills a hung command (rc $rc, ${el}s)" test "$rc" != 0 -a "$el" -lt 20
  check "lock released after a timeout" test ! -e "$TESTLOCK_DIR"
else
  ok "timeout test skipped (no timeout/gtimeout on PATH)"
fi

# 7. no command: usage error
"$TL" 2>/dev/null; check "no command is a usage error" test "$?" = 64

exit "$fail"
