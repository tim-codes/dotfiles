#!/bin/bash
# Exercise src/bin/squad-pr-merge against a stub `gh` on PATH — never the real
# gh. The stub answers `gh pr view` / `gh repo view` / `gh pr checks` from
# STUB_* variables and logs every other call, so a merge is visible as a logged
# `pr merge` line.
# Usage: bash tests/squad-pr-merge.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SRC_REPO/src/bin/squad-pr-merge"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; LOG="$T/calls.log"; mkdir -p "$BIN"

cat >"$BIN/gh" <<'STUB'
#!/bin/bash
echo "gh $*" >>"$GH_LOG"
case "$1 $2" in
  "pr view")   echo "${STUB_STATE:-OPEN} ${STUB_DRAFT:-false} ${STUB_BASE:-trunk/261025-1} ${STUB_HEAD:-feat/x}" ;;
  "repo view") echo "${STUB_DEFAULT:-main}" ;;
  "pr checks") [ "${STUB_CHECKS:-green}" = green ] && exit 0; echo "build fail" >&2; exit 1 ;;
  "pr merge")  exit 0 ;;
esac
STUB
chmod +x "$BIN/gh"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
TODAY="$(date +%F)"
R=Exxo-Labs/h2gc-portal

# run <description> <expected: refuse|merge> <log-must-match-or-empty> <env...> -- <args...>
run() {
  local d="$1" want="$2" pat="$3"; shift 3
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
  : >"$LOG"
  local out rc
  out="$(env -u SQUAD_MERGE_AUTHORITY -u SQUAD_ADOPTED_TRUNKS PATH="$BIN:$PATH" GH_LOG="$LOG" "${envs[@]}" bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [ "$want" = refuse ]; then
    if [ "$rc" -ne 0 ] && ! grep -q 'pr merge' "$LOG" && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]; then ok "$d"; else bad "$d (rc=$rc out=$out)"; fi
  else
    if [ "$rc" -eq 0 ] && grep -qE "$pat" "$LOG" && ! grep -q -- '--squash' <<<"$(grep 'pr merge' "$LOG" | grep -- "$NOT" )"; then ok "$d"; else bad "$d (rc=$rc out=$out log=$(cat "$LOG"))"; fi
  fi
}

NOT=zzz
run "into-trunk refuses base main"        refuse "" STUB_BASE=main -- 7 --repo $R --into-trunk
run "into-trunk refuses draft"            refuse "" STUB_DRAFT=true -- 7 --repo $R --into-trunk
run "into-trunk refuses red checks"       refuse "" STUB_CHECKS=red -- 7 --repo $R --into-trunk
run "into-trunk refuses unknown base"     refuse "" STUB_BASE=feat/automations-trunk -- 7 --repo $R --into-trunk
run "into-trunk refuses a closed PR"      refuse "" STUB_STATE=MERGED -- 7 --repo $R --into-trunk
run "into-trunk accepts adopted trunk"    merge "pr merge 7 -R $R --squash" STUB_BASE=feat/automations-trunk SQUAD_ADOPTED_TRUNKS="a/b, feat/automations-trunk" -- 7 --repo $R --into-trunk
run "into-trunk squashes, no grant needed" merge "pr merge 7 -R $R --squash" -- 7 --repo $R --into-trunk
NOT='--merge'
run "into-trunk never uses --merge"       merge "pr merge 7 -R $R --squash" -- 7 --repo $R --into-trunk
NOT=zzz
run "land refuses without grant"          refuse "" STUB_BASE=main STUB_HEAD=trunk/261025-1 -- 9 --repo $R --land
run "land refuses a grant for another repo" refuse "" STUB_BASE=main STUB_HEAD=trunk/261025-1 SQUAD_MERGE_AUTHORITY="Other/repo@$TODAY" -- 9 --repo $R --land
run "land refuses a stale grant"          refuse "" STUB_BASE=main STUB_HEAD=trunk/261025-1 SQUAD_MERGE_AUTHORITY="$R@2020-01-01" -- 9 --repo $R --land
run "land refuses non-default base"       refuse "" STUB_BASE=develop STUB_HEAD=trunk/261025-1 SQUAD_MERGE_AUTHORITY="$R@$TODAY" -- 9 --repo $R --land
run "land refuses non-trunk head"         refuse "" STUB_BASE=main STUB_HEAD=feat/x SQUAD_MERGE_AUTHORITY="$R@$TODAY" -- 9 --repo $R --land
run "land refuses draft"                  refuse "" STUB_BASE=main STUB_HEAD=trunk/261025-1 STUB_DRAFT=true SQUAD_MERGE_AUTHORITY="$R@$TODAY" -- 9 --repo $R --land
run "land refuses red checks"             refuse "" STUB_BASE=main STUB_HEAD=trunk/261025-1 STUB_CHECKS=red SQUAD_MERGE_AUTHORITY="$R@$TODAY" -- 9 --repo $R --land
NOT='--squash'
run "land uses --merge, never --squash"   merge "pr merge 9 -R $R --merge" STUB_BASE=main STUB_HEAD=trunk/261025-1 SQUAD_MERGE_AUTHORITY="$R@$TODAY" -- 9 --repo $R --land
run "land accepts bare date grant"        merge "pr merge 9 -R $R --merge" STUB_BASE=main STUB_HEAD=trunk/261025-1 SQUAD_MERGE_AUTHORITY="$TODAY" -- 9 --repo $R --land
NOT=zzz
run "bad mode refused"                    refuse "" -- 9 --repo $R
run "non-numeric PR refused"              refuse "" -- x --repo $R --land

: >"$LOG"
out="$(PATH="$BIN:$PATH" GH_LOG="$LOG" STUB_BASE=trunk/1-1 bash "$SCRIPT" 7 --repo $R --into-trunk --dry-run 2>&1)"
if grep -q -- "gh pr merge 7 -R $R --squash" <<<"$out" && ! grep -q 'pr merge' "$LOG"; then ok "dry-run prints, does not merge"; else bad "dry-run ($out)"; fi

[ "$fail" = 0 ] && echo "all squad-pr-merge tests passed"
exit "$fail"
