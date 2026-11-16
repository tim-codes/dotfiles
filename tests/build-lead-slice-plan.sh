#!/bin/bash
# Exercise the build-lead skill's references/slice-plan.sh on a small fixture plan.
# Usage: bash tests/build-lead-slice-plan.sh
set -uo pipefail
SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$SRC_REPO/files/claude/skills/build-lead/references/slice-plan.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

cat > "$T/plan.md" <<'P'
# Plan Title
Goal: x
## Global Constraints
GC-LINE
## Review Focus
RF-LINE
## Lanes
LANES-LINE
### Task X1: first
X1-BODY
### Task X2: second
X2-BODY
## Plan rulings
RULING-LINE
P

out=$("$S" "$T/plan.md" "$T/o" A one X2 X1) ; rc=$?
check "exits 0 and prints path" test "$rc" = 0 -a "$out" = "$T/o/lane-A-one.md"
f="$T/o/lane-A-one.md"
for s in "Plan Title" GC-LINE RF-LINE LANES-LINE X1-BODY X2-BODY RULING-LINE; do
  check "contains $s" grep -q -- "$s" "$f"
done
check "tasks in given order (X2 before X1)" test "$(grep -n 'X2-BODY' "$f" | cut -d: -f1)" -lt "$(grep -n 'X1-BODY' "$f" | cut -d: -f1)"
check "Lanes section stops before first Task heading after it" test "$(grep -c 'LANES-LINE' "$f")" = 1
"$S" "$T/plan.md" "$T/o" A bad X9 2>/dev/null; check "missing task heading fails" test "$?" != 0
"$S" "$T/nope.md" "$T/o" A bad X1 2>/dev/null; check "missing plan fails" test "$?" != 0
"$S" 2>/dev/null; check "no args exits 2" test "$?" = 2
exit $fail
