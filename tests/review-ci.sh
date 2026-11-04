#!/bin/bash
# Tests for src/bin/review-ci against fakes: `git`, `just`, `gh` and
# `worktree-copy-local-env` on PATH log their argv (and `just` its working directory) to one log;
# nothing touches a real checkout, repo or network. Usage: bash tests/review-ci.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
script=$here/../src/bin/review-ci
tmpdir=${TMPDIR:-/tmp}
tmp=$(mktemp -d "${tmpdir%/}/rcitest.XXXXXX")
trap 'rm -rf "${tmp:?}"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s: %s\n' "$1" "$2"; }

fakes=$tmp/bin; mkdir -p "$fakes"
cat > "$fakes/git" <<'SH'
#!/bin/bash
echo "git $*" >> "$FAKE_LOG"
# git -C <checkout> worktree add --detach <path> <sha> | worktree remove --force <path>
if [ "$3" = worktree ] && [ "$4" = add ]; then mkdir -p "$6"; fi
if [ "$3" = worktree ] && [ "$4" = remove ]; then rm -rf "$6"; fi
exit 0
SH
cat > "$fakes/just" <<'SH'
#!/bin/bash
echo "just $* (in $PWD)" >> "$FAKE_LOG"
echo "fake just output for $*"
[ "$1" = ci ] && exit "${FAKE_CI_EXIT:-0}"
exit 0
SH
cat > "$fakes/gh" <<'SH'
#!/bin/bash
echo "gh $*" >> "$FAKE_LOG"
SH
cat > "$fakes/worktree-copy-local-env" <<'SH'
#!/bin/bash
echo "worktree-copy-local-env $*" >> "$FAKE_LOG"
SH
chmod +x "$fakes"/*

SHA=0123456789abcdef0123456789abcdef01234567
checkout=$tmp/checkout; mkdir -p "$checkout"

run() { # run <case> [env...]; sets out, rc, log
  local c=$1; shift
  export FAKE_LOG=$tmp/$c.log; : > "$FAKE_LOG"
  scratch=$tmp/scratch-$c; mkdir -p "$scratch"
  out=$(env -u SQUAD_SCRATCH_DIR PATH="$fakes:$PATH" REVIEW_CI_SCRATCH_DIR="$scratch" "$@" "$script" "$checkout" "$SHA" 2>&1)
  rc=$?
  log=$(cat "$FAKE_LOG")
}
has() { printf '%s\n' "$log" | grep -qF -- "$1"; }

# 1. install then ci in a detached worktree of the sha, then the worktree is removed
run green
wt=$tmp/scratch-green/review-ci
good=1
for want in \
  "git -C $checkout fetch --quiet origin $SHA" \
  "git -C $checkout worktree add --detach $wt $SHA" \
  "worktree-copy-local-env $wt" \
  "just install (in $wt)" \
  "just ci (in $wt)" \
  "git -C $checkout worktree remove --force $wt"; do
  has "$want" || { bad "runs install then ci in a detached worktree of the sha and removes it" "missing: $want"; good=0; }
done
order=$(printf '%s\n' "$log" | grep -n 'just ' | cut -d: -f2- | tr '\n' '|')
[ "$order" = "just install (in $wt)|just ci (in $wt)|" ] || { bad "install before ci" "$order"; good=0; }
[ "$rc" = 0 ] || { bad "green exit" "rc $rc"; good=0; }
[ ! -e "$wt" ] || { bad "green worktree removed" "$wt still there"; good=0; }
printf '%s\n' "$out" | grep -qF 'review-ci: exit 0' || { bad "green summary" "$out"; good=0; }
[ -s "$tmp/scratch-green/review-ci.log" ] || { bad "green log" "no review-ci.log"; good=0; }
[ "$good" = 1 ] && ok "review-ci runs install then ci in a detached worktree of the sha and removes it"

# 2. a red ci: non-zero, the worktree still removed, the tail and exit printed
run red FAKE_CI_EXIT=3
wt=$tmp/scratch-red/review-ci
good=1
[ "$rc" = 3 ] || { bad "red exit" "rc $rc"; good=0; }
[ ! -e "$wt" ] || { bad "red worktree removed" "$wt still there"; good=0; }
has "git -C $checkout worktree remove --force $wt" || { bad "red remove" "$log"; good=0; }
printf '%s\n' "$out" | grep -qF 'review-ci: exit 3' || { bad "red summary" "$out"; good=0; }
printf '%s\n' "$out" | grep -qF 'fake just output for ci' || { bad "red tail" "$out"; good=0; }
[ "$good" = 1 ] && ok "review-ci exits non-zero and still removes the worktree when ci fails"

# 3. a leftover worktree from an earlier run is removed first
export FAKE_LOG=$tmp/leftover.log; : > "$FAKE_LOG"
mkdir -p "$tmp/scratch-left/review-ci"
env PATH="$fakes:$PATH" REVIEW_CI_SCRATCH_DIR="$tmp/scratch-left" "$script" "$checkout" "$SHA" >/dev/null 2>&1
first=$(grep -n 'worktree' "$FAKE_LOG" | head -1)
case "$first" in *"worktree remove --force $tmp/scratch-left/review-ci"*) ok "review-ci removes a leftover worktree first" ;;
  *) bad "review-ci removes a leftover worktree first" "$first" ;; esac

# 4. no scratch dir: refused before anything runs; a bad sha too
export FAKE_LOG=$tmp/noscratch.log; : > "$FAKE_LOG"
out=$(env -u REVIEW_CI_SCRATCH_DIR -u SQUAD_SCRATCH_DIR PATH="$fakes:$PATH" "$script" "$checkout" "$SHA" 2>&1); rc=$?
if [ "$rc" != 0 ] && [ ! -s "$FAKE_LOG" ] && printf '%s' "$out" | grep -q REVIEW_CI_SCRATCH_DIR; then
  ok "review-ci refuses without REVIEW_CI_SCRATCH_DIR"
else bad "review-ci refuses without REVIEW_CI_SCRATCH_DIR" "rc $rc, log $(cat "$FAKE_LOG"), out $out"; fi
out=$(env PATH="$fakes:$PATH" REVIEW_CI_SCRATCH_DIR="$tmp" "$script" "$checkout" '--upload-pack=x' 2>&1); rc=$?
if [ "$rc" != 0 ] && [ ! -s "$FAKE_LOG" ]; then ok "review-ci refuses a sha that is not hex"
else bad "review-ci refuses a sha that is not hex" "rc $rc"; fi
out=$(env PATH="$fakes:$PATH" REVIEW_CI_SCRATCH_DIR="$tmp" "$script" "$checkout" "${SHA:0:12}" 2>&1); rc=$?
if [ "$rc" != 0 ] && [ ! -s "$FAKE_LOG" ] && printf '%s' "$out" | grep -q '40 hex'; then
  ok "review-ci refuses an abbreviated sha"
else bad "review-ci refuses an abbreviated sha" "rc $rc, out $out"; fi

# 4b. a sha that is 40 characters but not all hex is refused
export FAKE_LOG=$tmp/nothex40.log; : > "$FAKE_LOG"
out=$(env PATH="$fakes:$PATH" REVIEW_CI_SCRATCH_DIR="$tmp" "$script" "$checkout" "${SHA:0:39}g" 2>&1); rc=$?
if [ "$rc" != 0 ] && [ ! -s "$FAKE_LOG" ] && printf '%s' "$out" | grep -q '40 hex'; then
  ok "review-ci refuses a 40-character sha that is not hex"
else bad "review-ci refuses a 40-character sha that is not hex" "rc $rc, out $out"; fi

# 4c. SQUAD_SCRATCH_DIR still works as the fallback
export FAKE_LOG=$tmp/squadfallback.log; : > "$FAKE_LOG"
mkdir -p "$tmp/scratch-squad"
out=$(env -u REVIEW_CI_SCRATCH_DIR SQUAD_SCRATCH_DIR="$tmp/scratch-squad" PATH="$fakes:$PATH" "$script" "$checkout" "$SHA" 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -s "$tmp/scratch-squad/review-ci.log" ] && grep -qF "just ci (in $tmp/scratch-squad/review-ci)" "$FAKE_LOG"; then
  ok "review-ci falls back to SQUAD_SCRATCH_DIR"
else bad "review-ci falls back to SQUAD_SCRATCH_DIR" "rc $rc, out $out"; fi

# 5. nothing is pushed, tagged or sent to GitHub
all=$(cat "$tmp"/*.log)
if printf '%s\n' "$all" | grep -Eq '^git .*\b(push|tag)\b|^gh '; then
  bad "review-ci runs no git push or tag and no gh" "$(printf '%s\n' "$all" | grep -E 'push|tag|^gh ')"
else ok "review-ci runs no git push or tag and no gh"; fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
