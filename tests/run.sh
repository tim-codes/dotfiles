#!/bin/bash
# Run the whole suite: every tests/*.sh (bash) and tests/test_*.py (python3 -I), discovered by
# pattern so a new test file is picked up with no edit here. CI and humans run this same entry
# point. Exits non-zero if any test fails; a test whose prerequisite is missing is SKIPPED with
# a printed reason, never silently. Output of a passing test is hidden (-v shows it).
# Usage: bash tests/run.sh [-v] [name-filter ...]     e.g. bash tests/run.sh claude-sync
# Env:   TESTS_KNOWN_FAILING  space-separated test names expected to fail (reported, not fatal)
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
verbose=0
if [ "${1:-}" = -v ]; then verbose=1; shift; fi
filters=("$@")

# skip_reason <test-file-name>: print why the test cannot run here, or nothing if it can.
skip_reason() {
  local missing="" t
  for t in $(needs "$1"); do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
  [ -n "$missing" ] && printf 'missing tool(s):%s\n' "$missing"
}
# needs <test-file-name>: external tools the test cannot do without (declared here, not in the tests).
needs() {
  case "$1" in
    claude-kickoff*.sh|claude-sync-*.sh|squad-hooks-settings.sh|claude-config*) echo "jq" ;;
    claude-openrouter-wrapper.sh) echo "fish zsh" ;;
    squad-config-parity.sh) echo "yq" ;;
  esac
}

pass=0; fail=0; skipped=0; known=0
failed=(); skips=()
for f in "$here"/*.sh "$here"/test_*.py; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  [ "$name" = run.sh ] && continue
  if [ ${#filters[@]} -gt 0 ]; then
    hit=0; for p in "${filters[@]}"; do case "$name" in *"$p"*) hit=1 ;; esac; done
    [ $hit = 1 ] || continue
  fi
  reason=$(skip_reason "$name")
  if [ -n "$reason" ]; then
    printf 'SKIP  %s: %s\n' "$name" "$reason"; skipped=$((skipped + 1)); skips+=("$name"); continue
  fi
  case "$name" in
    *.py) cmd=(python3 -I "$f") ;;
    *)    cmd=(bash "$f") ;;
  esac
  out=$(mktemp "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
  start=$SECONDS
  "${cmd[@]}" >"$out" 2>&1 </dev/null; rc=$?
  secs=$((SECONDS - start))
  # A test that skips parts of itself says so with a "skip:" line; surface those.
  grep -i '^skip' "$out" | sed "s/^/      ($name) /"
  if [ $rc -eq 0 ]; then
    printf 'PASS  %s (%ss)\n' "$name" "$secs"; pass=$((pass + 1))
    [ $verbose = 1 ] && cat "$out"
  elif case " ${TESTS_KNOWN_FAILING:-} " in *" $name "*) true ;; *) false ;; esac; then
    printf 'KNOWN-FAIL  %s (%ss, exit %s): listed in TESTS_KNOWN_FAILING\n' "$name" "$secs" "$rc"; known=$((known + 1))
  else
    printf 'FAIL  %s (%ss, exit %s)\n' "$name" "$secs" "$rc"; fail=$((fail + 1)); failed+=("$name")
    grep -v '^ok' "$out" | tail -40 | sed 's/^/    | /'
  fi
  rm -f "$out"
done

printf '\n%s passed, %s failed, %s skipped, %s known-failing\n' "$pass" "$fail" "$skipped" "$known"
[ ${#skips[@]} -gt 0 ] && printf 'skipped: %s\n' "${skips[*]}"
[ ${#failed[@]} -gt 0 ] && { printf 'FAILED: %s\n' "${failed[*]}"; exit 1; }
exit 0
