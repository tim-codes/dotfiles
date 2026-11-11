#!/bin/bash
# Exercise scripts/worktree-closedown against throwaway git repos (a bare
# "origin" reached through a git@github.com insteadOf rewrite), a fake $HOME
# with a fake Claude context dir, and a stubbed `gh` on PATH — never a real
# repo, remote or context. `wt` is the real worktrunk behind a thin wrapper
# that records whether the transcripts had already moved when it was called.
# Usage: bash tests/worktree-closedown.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CD="$SRC_REPO/scripts/worktree-closedown"
REAL_WT="$(command -v wt)" || { echo "SKIP: wt (worktrunk) not on PATH"; exit 0; }
command -v jq >/dev/null || { echo "SKIP: jq not on PATH"; exit 0; }
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; FAKE="$T/home"
mkdir -p "$BIN" "$FAKE/.claude-personal/projects"

export HOME="$FAKE" GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1 REAL_WT T
export XDG_CONFIG_HOME="$FAKE/.config"
git config --global user.name test
git config --global user.email test@example.invalid
git config --global commit.gpgsign false
git config --global init.defaultBranch main
git config --global protocol.file.allow always

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
stub() { printf '#!/bin/bash\n%s\n' "$2" >"$BIN/$1"; chmod +x "$BIN/$1"; }
slug() { printf '%s' "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }

# gh: answer `gh pr list` with $GH_JSON, log every call.
stub gh 'echo "$*" >>"$T/gh.log"; printf "%s\n" "${GH_JSON:-[]}"'
# wt: note whether the sentinel transcript is already relocated, then either
# fail like a submodule refusal (WT_FAIL_SUBMODULE=1) or run the real wt.
stub wt '[ -n "${SENTINEL:-}" ] && { [ -f "$SENTINEL" ] && echo moved || echo not-moved; } >>"$T/wt.order"
echo "$*" >>"$T/wt.log"
if [ "${WT_FAIL_SUBMODULE:-0}" = 1 ]; then echo "fatal: working trees containing submodules cannot be moved or removed" >&2; exit 1; fi
exec "$REAL_WT" "$@"'
export PATH="$BIN:$PATH"

n=0
# new_repo: fresh origin + primary checkout P and a worktree W on branch B with
# one commit. Sets P W B.
new_repo() {
    n=$((n + 1))
    local o="$T/r$n/origin.git"
    P="$T/r$n/repo"; W="$T/r$n/repo-feat"; B="feat/x$n"
    git init -q --bare "$o"
    git config --global "url.$o.insteadOf" "git@github.com:tim/fake$n.git"
    git init -q "$P"
    git -C "$P" commit -q --allow-empty -m init
    git -C "$P" remote add origin "git@github.com:tim/fake$n.git"
    git -C "$P" push -q origin main
    git -C "$P" remote set-head origin main >/dev/null
    git -C "$P" worktree add -q -b "$B" "$W"
    echo change >"$W/file"; git -C "$W" add file; git -C "$W" commit -q -m change
}
merge_ff() { git -C "$P" push -q origin "$B:main"; }               # ancestor merge
merge_squash() { git -C "$P" push -q origin "$(git -C "$P" commit-tree -p main -m squash "$B^{tree}"):refs/heads/main"; }
tip() { git -C "$P" rev-parse "$B"; }
pr_json() { printf '[{"number":7,"headRefOid":"%s","url":"https://github.com/tim/fake/pull/7"}]' "$1"; }
has_branch() { git -C "$P" rev-parse --verify --quiet "refs/heads/$B" >/dev/null; }
intact() { [ -d "$W" ] && has_branch; }
run() { "$CD" "$@" >"$T/out" 2>&1; }
says() { grep -q -- "$1" "$T/out"; }

# 1. dirty tree (untracked file) refused
new_repo; merge_ff; echo x >"$W/untracked"
run "$P" "$B"; rc=$?
check "dirty tree refused (exit 1)" test "$rc" = 1
check "dirty tree: reason given" says "uncommitted or untracked"
check "dirty tree: nothing deleted" intact

# 2. unmerged branch refused (no merged PR)
new_repo; GH_JSON='[]' run "$P" "$B"; rc=$?
check "unmerged branch refused" test "$rc" = 1
check "unmerged: reason given" says "is not merged"
check "unmerged: nothing deleted" intact

# 3. squash-merged PR whose head != local tip refused
new_repo; merge_squash; old="$(tip)"
echo more >>"$W/file"; git -C "$W" commit -qam more
GH_JSON="$(pr_json "$old")" run "$P" "$B"; rc=$?
check "squash PR head != tip refused" test "$rc" = 1
check "squash mismatch: reason given" says "head is not the local tip"
check "squash mismatch: nothing deleted" intact

# 4. primary checkout and default branch refused
new_repo; merge_ff
run "$P" "$P"; rc=$?
check "primary checkout refused" test "$rc" = 1 -a -d "$P"
check "primary: reason given" says "primary checkout"
git -C "$P" worktree add -q -f "$T/r$n/main2" main
run "$P" main; rc=$?
check "default branch refused" test "$rc" = 1 -a -d "$T/r$n/main2"
check "default branch: reason given" says "is the default branch"

# 5. relative repo path and unknown target refused before anything else
run "repo" "$B"; rc=$?
check "relative repo path is a usage error (exit 2)" test "$rc" = 2
run "$P" no/such-branch; rc=$?
check "unknown branch refused" test "$rc" = 1

# 6. unset origin/HEAD refused (no guessing main/master)
git -C "$P" remote set-head origin --delete
run "$P" "$B"; rc=$?
check "unset origin/HEAD refused" test "$rc" = 1
check "unset origin/HEAD: reason given" says "origin/HEAD is not set"
check "unset origin/HEAD: nothing deleted" intact

# 7. dry run on a mergeable worktree deletes nothing
new_repo; merge_ff
uuid=11111111-2222-3333-4444-555555555555
src="$FAKE/.claude-personal/projects/$(slug "$W")"; mkdir -p "$src"
printf '{"cwd":"%s","x":1}\n' "$W" >"$src/$uuid.jsonl"
: >"$T/wt.log"
run --dry-run "$P" "$B"; rc=$?
check "dry run passes (exit 0)" test "$rc" = 0
check "dry run names the session it would relocate" says "$uuid"
check "dry run: worktree and branch intact" intact
check "dry run: transcript not moved" test -f "$src/$uuid.jsonl"
check "dry run: wt never called" test ! -s "$T/wt.log"

# 8. ancestor-merged succeeds; transcripts relocated before removal
dst="$FAKE/.claude-personal/projects/$(slug "$P")/$uuid.jsonl"
: >"$T/wt.order"
SENTINEL="$dst" run "$P" "$B"; rc=$?
check "ancestor-merged closes down (exit 0)" test "$rc" = 0 || cat "$T/out"
check "ancestor: worktree removed" test ! -e "$W"
check "ancestor: branch deleted" bash -c '! git -C "$1" rev-parse --verify --quiet "refs/heads/$2" >/dev/null' _ "$P" "$B"
check "ancestor: gh not needed" bash -c '! grep -q -- "--head '"$B"'" "$T/gh.log" 2>/dev/null'
check "transcript relocated to primary slug" test -f "$dst"
check "transcript cwd rewritten to primary" grep -qF "\"cwd\":\"$P\"" "$dst"
check "transcripts moved BEFORE wt remove" test "$(cat "$T/wt.order")" = moved
check "report names the session and removal" bash -c 'grep -q "'"$uuid"'" "$1" && grep -q "worktree removed" "$1" && grep -q "branch deleted" "$1"' _ "$T/out"
check "remote branch list untouched" test "$(git -C "$P" ls-remote --heads origin | wc -l | tr -d ' ')" = 1

# 9. squash-merged with head == tip succeeds, by worktree path
new_repo; merge_squash
GH_JSON="$(pr_json "$(tip)")" run "$P" "$W"; rc=$?
check "squash-merged (head == tip) closes down" test "$rc" = 0 || cat "$T/out"
check "squash: worktree removed and branch deleted" bash -c '[ ! -e "$1" ] && ! git -C "$2" rev-parse --verify --quiet "refs/heads/$3" >/dev/null' _ "$W" "$P" "$B"
check "squash: gh queried with -R owner/repo --head --state merged" grep -q -- "-R tim/fake$n --head $B --state merged" "$T/gh.log"

# 10. submodules: dirty submodule refused; clean one removed via the fallback
new_repo
sub="$T/r$n/sub.git"; git init -q --bare "$sub"
git clone -q "$sub" "$T/r$n/subwork" 2>/dev/null
git -C "$T/r$n/subwork" commit -q --allow-empty -m s; git -C "$T/r$n/subwork" push -q origin HEAD:main
git -C "$W" submodule -q add "$sub" vendor/sub
git -C "$W" commit -qm "add submodule"
merge_ff
echo dirt >"$W/vendor/sub/dirt"
run "$P" "$B"; rc=$?
check "dirty submodule refused" test "$rc" = 1
# The superproject's own status already lists a dirty submodule, so either
# refusal message is right here; the foreach check is pinned down below.
check "dirty submodule: reason given" says "vendor/sub"
check "dirty submodule: nothing deleted" intact
rm "$W/vendor/sub/dirt"
git -C "$W/vendor/sub" commit -q --allow-empty -m local-only
run "$P" "$B"; rc=$?
check "submodule local-only commit refused" test "$rc" = 1 && says "local-only commit"
git -C "$W/vendor/sub" reset -q --hard origin/main
git -C "$W/vendor/sub" checkout -q --detach origin/main
# A local-only commit on a side branch: the superproject status is clean (the
# submodule HEAD is unchanged), so only the foreach check can see it.
git -C "$W/vendor/sub" branch -q side; git -C "$W/vendor/sub" checkout -q side
git -C "$W/vendor/sub" commit -q --allow-empty -m side-only
git -C "$W/vendor/sub" checkout -q --detach origin/main
check "superproject status clean with side-branch commit" test -z "$(git -C "$W" status --porcelain)"
run "$P" "$B"; rc=$?
check "submodule side-branch local-only commit refused" test "$rc" = 1
check "side-branch: refused by the submodule check" says "submodule in .* holds unsaved work"
git -C "$W/vendor/sub" branch -q -D side
WT_FAIL_SUBMODULE=1 run "$P" "$B"; rc=$?
check "submodule fallback closes down" test "$rc" = 0 || cat "$T/out"
check "submodule fallback: worktree gone, pruned, branch deleted" bash -c '[ ! -e "$1" ] && ! git -C "$2" worktree list | grep -qF "$1" && ! git -C "$2" rev-parse --verify --quiet "refs/heads/$3" >/dev/null' _ "$W" "$P" "$B"
check "submodule fallback: named in the report" says "submodule fallback"

# 11. a non-submodule wt failure is not papered over with rm -rf
new_repo; merge_ff
WT_FAIL_SUBMODULE=1 run "$P" "$B"; rc=$?
check "wt failure without .gitmodules fails, worktree kept" test "$rc" = 1 -a -d "$W"

[ "$fail" -eq 0 ] && echo "all worktree-closedown tests passed"
exit "$fail"
