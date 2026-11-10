#!/bin/bash
# Tests for scripts/claude-scratch-persist and scripts/claude-scratch-gc under a fake
# $HOME and fake tmp root (CLAUDE_SCRATCH_TMP_ROOT / CLAUDE_SCRATCH_ROOT); nothing real
# is touched. Cases: a fresh session gets the durable dir and a tmp symlink; an existing
# tmp scratchpad with files is migrated then symlinked; a foreign symlink is untouched;
# the Stop fallback copies a real directory and mirrors .superpowers/sdd; gc dry-run
# lists without deleting, --apply deletes old unpinned sessions only, a pinned or young
# session survives; the log line is written.
# Usage: bash tests/claude-scratch-persist.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSIST="$SRC_REPO/scripts/claude-scratch-persist"
GC="$SRC_REPO/scripts/claude-scratch-gc"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" CLAUDE_SCRATCH_TMP_ROOT="$T/tmp/claude-1" CLAUDE_SCRATCH_ROOT="$T/home/scratch/claude"
mkdir -p "$HOME" "$T/proj/.superpowers/sdd"
fail=0
ok() { printf 'ok: %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d=$1; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

CWD="$T/proj"
SLUG="$(printf '%s' "$CWD" | sed 's/[^A-Za-z0-9]/-/g')"
hook() { printf '{"session_id":"%s","cwd":"%s"}' "$2" "$CWD" | "$PERSIST" "$1"; }
TMP_PAD() { echo "$CLAUDE_SCRATCH_TMP_ROOT/$SLUG/$1/scratchpad"; }
DUR() { echo "$CLAUDE_SCRATCH_ROOT/$SLUG/$1"; }

# 1. fresh session
out="$(hook start s-fresh)"
check "fresh: silent on stdout" test -z "$out"
check "fresh: durable dir exists" test -d "$(DUR s-fresh)/scratchpad"
check "fresh: tmp scratchpad is a symlink to durable" test "$(readlink "$(TMP_PAD s-fresh)")" = "$(DUR s-fresh)/scratchpad"
echo hi >"$(TMP_PAD s-fresh)/f.txt"
check "fresh: a write through the symlink lands durable" test -f "$(DUR s-fresh)/scratchpad/f.txt"
hook start s-fresh
check "fresh: second run keeps the link" test "$(readlink "$(TMP_PAD s-fresh)")" = "$(DUR s-fresh)/scratchpad"

# 2. migration
mkdir -p "$(TMP_PAD s-mig)/sub"; echo a >"$(TMP_PAD s-mig)/a.txt"; echo b >"$(TMP_PAD s-mig)/sub/b.txt"
hook start s-mig
check "migrate: tmp is now a symlink" test -L "$(TMP_PAD s-mig)"
check "migrate: files moved durable" test -f "$(DUR s-mig)/scratchpad/a.txt" -a -f "$(DUR s-mig)/scratchpad/sub/b.txt"
check "migrate: content intact" test "$(cat "$(TMP_PAD s-mig)/a.txt")" = a

# 3. foreign symlink
mkdir -p "$T/elsewhere" "$(dirname "$(TMP_PAD s-foreign)")"; ln -s "$T/elsewhere" "$(TMP_PAD s-foreign)"
hook start s-foreign; hook stop s-foreign
check "foreign: symlink untouched" test "$(readlink "$(TMP_PAD s-foreign)")" = "$T/elsewhere"
check "foreign: target gained nothing" test -z "$(ls -A "$T/elsewhere")"

# 4. stop fallback + sdd mirror
mkdir -p "$(TMP_PAD s-stop)"; echo c >"$(TMP_PAD s-stop)/c.txt"; echo led >"$CWD/.superpowers/sdd/ledger.md"
hook stop s-stop
check "stop: real dir copied durable" test -f "$(DUR s-stop)/scratchpad/c.txt"
check "stop: real dir left in place (not replaced)" test -d "$(TMP_PAD s-stop)" -a ! -L "$(TMP_PAD s-stop)"
check "stop: sdd ledger mirrored" test -f "$(DUR s-stop)/sdd/ledger.md"
check "log written" grep -q 'migrated' "$HOME/.local/state/claude-scratch/persist.log"

# 5. gc
old="$(date -v-40d +%Y%m%d%H%M 2>/dev/null || date -d '40 days ago' +%Y%m%d%H%M)"
for s in s-fresh s-mig s-stop; do find "$(DUR $s)" -exec touch -h -t "$old" {} +; done
touch "$(DUR s-mig)/.pin"; touch -t "$old" "$(DUR s-mig)/.pin"; touch -t "$old" "$(DUR s-mig)"
mkdir -p "$(DUR s-young)/scratchpad"; echo y >"$(DUR s-young)/scratchpad/y"
touch -t "$old" "$(DUR s-fresh)/scratchpad/f.txt"
out="$("$GC")"
check "gc dry-run: lists would-delete" grep -q 's-fresh.*would delete' <<<"$out"
check "gc dry-run: deletes nothing" test -d "$(DUR s-fresh)" -a -d "$(DUR s-stop)"
out="$("$GC" --apply)"
check "gc apply: old unpinned deleted" test ! -e "$(DUR s-fresh)" -a ! -e "$(DUR s-stop)"
check "gc apply: pinned survives" test -f "$(DUR s-mig)/scratchpad/a.txt"
check "gc apply: young survives" test -f "$(DUR s-young)/scratchpad/y"
check "gc apply: nothing outside root touched" test -d "$T/elsewhere" -a -d "$T/proj"
check "gc: bad --older-than rejected" bash -c "! '$GC' --older-than abc 2>/dev/null"
exit $fail
