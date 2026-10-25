#!/bin/bash
# Table-driven tests for scripts/claude-openrouter-guard, the PreToolUse hook
# that stops exxo-openrouter (Kimi K3) workers merging PRs or pushing to the
# default branch. Uses temp git repos with a local bare origin and a fake
# $HOME; never touches the real contexts and never runs the commands under
# test — the guard only parses them.
# Usage: bash tests/claude-openrouter-guard.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$SRC_REPO/scripts/claude-openrouter-guard"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export SQUAD_GUARD_LOG="$T/log/guard.jsonl"
mkdir -p "$HOME"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

g() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@" >/dev/null 2>&1; }

# origin.git: bare, default branch main, plus job/x. main-clone is on main,
# job-clone on job/x. trunk-clone's origin/HEAD points at "trunk".
g init -q --bare -b main "$T/origin.git"
g init -q -b main "$T/seed"
g -C "$T/seed" commit -q --allow-empty -m init
g -C "$T/seed" branch job/x
g -C "$T/seed" branch trunk
g -C "$T/seed" remote add origin "$T/origin.git"
g -C "$T/seed" push -q origin main job/x trunk
g clone -q "$T/origin.git" "$T/main-clone"
g clone -q -b job/x "$T/origin.git" "$T/job-clone"
g clone -q -b job/x "$T/origin.git" "$T/trunk-clone"
g -C "$T/trunk-clone" remote set-head origin trunk
mkdir -p "$T/job-clone/sub"
[ "$(git -C "$T/main-clone" rev-parse --abbrev-ref HEAD)" = main ] || bad "fixture: main-clone not on main"
[ "$(git -C "$T/job-clone" rev-parse --abbrev-ref HEAD)" = job/x ] || bad "fixture: job-clone not on job/x"

# run_guard <cwd> <command> [tool] -> prints "deny" or "allow"
run_guard() {
    local cwd="$1" cmd="$2" tool="${3:-Bash}" out rc
    out="$(jq -n --arg c "$cmd" --arg d "$cwd" --arg t "$tool" \
        '{session_id:"sess-1", cwd:$d, hook_event_name:"PreToolUse", tool_name:$t, tool_input:{command:$c}}' \
        | "$GUARD" 2>"$T/stderr")"
    rc=$?
    if [ "$rc" = 2 ] || jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$out" >/dev/null 2>&1; then
        echo deny
    elif [ "$rc" = 0 ] && [ -z "$out" ]; then
        echo allow
    else
        echo "unexpected(rc=$rc out=$out)"
    fi
}

# expect <deny|allow> <cwd-key> <command>; cwd-key: main | job | trunk
expect() {
    local want="$1" key="$2" cmd="$3" got
    got="$(run_guard "$T/$key-clone" "$cmd")"
    if [ "$got" = "$want" ]; then ok "$want [$key] $cmd"; else bad "want $want, got $got [$key] $cmd"; fi
}

[ -x "$GUARD" ] || { bad "guard missing or not executable: $GUARD"; exit 1; }

# --- BLOCK -----------------------------------------------------------------
while IFS='|' read -r key cmd; do
    [ -z "$key" ] && continue
    expect deny "$key" "$cmd"
done <<'TABLE'
job|gh pr merge 1
job|gh pr merge --squash --delete-branch 12
job|gh -R o/r pr merge 1
job|gh --repo o/r pr merge 1
job|gh --repo=o/r pr merge 1
job|gh pr -R o/r merge 1
job|gh pr --repo o/r merge --auto 1
job|curl -X PUT https://api.github.com/repos/o/r/pulls/1/merge
job|git -c alias.p=push p origin main
job|cd x && gh pr merge 1
job|true || gh pr merge 1
job|true; gh pr merge 1
job|echo y | gh pr merge 1
job|sleep 1 & gh pr merge 1
job|sh -c 'gh pr merge 1'
job|bash -c "git push origin main"
job|zsh -c 'git push origin master'
job|bash -lc 'gh pr merge 1'
job|eval "gh pr merge 1"
job|echo "$(gh pr merge 1)"
job|x=$(gh pr merge 1)
job|echo `gh pr merge 1`
job|gh api -X PUT repos/o/r/pulls/1/merge
job|gh api --method PUT repos/o/r/pulls/1/merge
job|gh api repos/o/r/pulls/1/merge
job|gh api /repos/{owner}/{repo}/pulls/7/merge -f merge_method=squash
job|git push origin main
job|git push origin master
job|git push origin HEAD:main
job|git push origin job/x:refs/heads/main
job|git push origin +main
job|git push origin :main
job|git push origin --delete main
job|git push --all
job|git push --mirror origin
job|git push -f origin HEAD:refs/heads/master
job|git -C . push origin HEAD:main
job|git -c push.default=current push origin main
job|git --git-dir=.git push origin main
job|timeout 5 git push origin master
job|timeout -s KILL 5 git push origin main
job|nice -n 5 git push origin main
job|nohup git push origin main
job|command git push origin main
job|env FOO=1 git push origin main
job|FOO=1 git push origin main
job|/usr/bin/git push origin main
job|/opt/homebrew/bin/git push origin main
job|git push origin main 2>&1 | tail -1
main|git push
main|git push -u origin
main|git push origin HEAD
main|git push origin @
main|cd ../job-clone && cd ../main-clone && git push
job|cd ../main-clone && git push
job|git -C ../main-clone push
job|git -C ../main-clone push origin HEAD
trunk|git push origin trunk
trunk|git push origin HEAD:trunk
trunk|git push origin main
job|git push origin "$BRANCH"
job|git push origin 'unbalanced
job|gh pr merge "unbalanced
job|echo main | xargs git push origin
TABLE

# --- ALLOW -----------------------------------------------------------------
while IFS='|' read -r key cmd; do
    [ -z "$key" ] && continue
    expect allow "$key" "$cmd"
done <<'TABLE'
job|git push origin job/smoke-1
job|git push -u origin job/x
job|git push
job|git push origin HEAD
job|git push -u origin HEAD
job|git -C sub push
job|gh pr view 1
job|gh pr list
job|gh pr create --draft
job|gh pr create --draft --title "merge main into job" --body "no push to main"
job|git merge main
job|git merge origin/main
job|git log main
job|git fetch origin main
job|git pull origin main
job|echo "gh pr merge"
job|echo 'git push origin main'
job|gh api repos/o/r/pulls/1
job|gh api repos/o/r/pulls/1/reviews
job|gh pr -R o/r view 1
job|curl https://api.github.com/repos/o/r/pulls/1
job|git -c alias.st=status st
job|ls; git status && git diff main
job|echo 'unbalanced
TABLE

# --- Non-Bash tool ---------------------------------------------------------
got="$(run_guard "$T/job-clone" "gh pr merge 1" Write)"
if [ "$got" = allow ]; then ok "non-Bash tool passes"; else bad "non-Bash tool: got $got"; fi

# --- Log (Plan E O9): guard.jsonl, no command text, blocks + allowed pushes -
L="$SQUAD_GUARD_LOG"
lines() { [ -f "$L" ] && wc -l <"$L" | tr -d ' ' || echo 0; }
# logcheck <name> <command> <jq predicate on the single new line> [cwd-key]
logcheck() {
    local name="$1" cmd="$2" pred="$3" key="${4:-job}"
    rm -f "$L"
    run_guard "$T/$key-clone" "$cmd" >/dev/null
    if [ "$(lines)" = 1 ] && jq -e --arg d "$T/$key-clone" "$pred" "$L" >/dev/null 2>&1; then
        ok "$name"
    else
        bad "$name: $(cat "$L" 2>/dev/null)"
    fi
}
# shellcheck disable=SC2016  # literal text, not expanded
SHAPE='(keys == ["cwd","decision","form","rule","session_id","target","ts"]) and (.ts | type == "string") and .session_id == "sess-1" and .cwd == $d'

logcheck "block_is_logged_without_command_text: fields" \
    'OPENROUTER_API_KEY=sk-or-TEST-PLACEHOLDER gh pr merge 42' \
    "$SHAPE"' and .rule == "gh-pr-merge" and .target == "42" and .decision == "block"'
if grep -q 'sk-or-' "$L" || grep -q 'pr merge' "$L" || grep -q OPENROUTER_API_KEY "$L"; then
    bad "block_is_logged_without_command_text: command text leaked"
else
    ok "block_is_logged_without_command_text: no command text"
fi
logcheck "log: push block, plain form" 'git push origin main' \
    "$SHAPE"' and .rule == "push-default-branch" and .target == "main" and .form == "plain" and .decision == "block"'
logcheck "log: git-C form" 'git -C . push origin HEAD:main' \
    '.rule == "push-default-branch" and .target == "main" and .form == "git-C"'
logcheck "log: sh-c form" "sh -c 'gh pr merge 3'" \
    '.rule == "gh-pr-merge" and .target == "3" and .form == "sh-c"'
logcheck "log: compound form" 'cd x && gh pr merge 1' \
    '.rule == "gh-pr-merge" and .target == "1" and .form == "compound"'
logcheck "log: other form (wrapper)" 'timeout 5 git push origin master' \
    '.rule == "push-default-branch" and .target == "master" and .form == "other"'
logcheck "log: gh api merge target is the PR number" 'gh api -X PUT repos/o/r/pulls/9/merge' \
    '.rule == "gh-api-merge" and .target == "9" and .decision == "block"'
logcheck "log: bare push on main targets main" 'git push' \
    '.rule == "push-default-branch" and .target == "main" and .decision == "block"' main
logcheck "allowed_job_push_logged_as_allow: explicit refspec" 'git push origin job/x' \
    "$SHAPE"' and .rule == "push-default-branch" and .target == "job/x" and .form == "plain" and .decision == "allow"'
logcheck "allowed_job_push_logged_as_allow: bare push" 'git push -u origin' \
    '.decision == "allow" and .target == "job/x"'

rm -f "$L"
run_guard "$T/job-clone" "gh pr view 1" >/dev/null
run_guard "$T/job-clone" "git status" >/dev/null
if [ "$(lines)" = 0 ]; then ok "non-push allow writes no log line"; else bad "non-push allow wrote a log line"; fi

# Default location and modes: ~/.local/state/claude-openrouter/guard.jsonl, dir 0700, file 0600.
( unset SQUAD_GUARD_LOG; run_guard "$T/job-clone" "gh pr merge 1" >/dev/null )
DL="$HOME/.local/state/claude-openrouter/guard.jsonl"
if [ -f "$DL" ] && [ "$(stat -f %Lp "$(dirname "$DL")")" = 700 ] && [ "$(stat -f %Lp "$DL")" = 600 ]; then
    ok "default log path with dir 0700 / file 0600"
else
    bad "default log path or modes wrong"
fi

# unwritable_log_still_blocks
mkdir -p "$T/ro"; chmod 500 "$T/ro"
got="$(SQUAD_GUARD_LOG="$T/ro/sub/guard.jsonl" run_guard "$T/job-clone" "gh pr merge 1")"
chmod 700 "$T/ro"
if [ "$got" = deny ]; then ok "unwritable_log_still_blocks"; else bad "unwritable_log_still_blocks: got $got"; fi

# The deny reason is one line naming the rule.
reason="$(jq -n --arg d "$T/job-clone" '{cwd:$d, tool_name:"Bash", tool_input:{command:"git push origin main"}}' \
    | "$GUARD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')"
if [ -n "$reason" ] && [ "$(printf '%s' "$reason" | wc -l | tr -d ' ')" = 0 ] && grep -q 'push-default-branch' <<<"$reason"; then
    ok "deny reason is one line naming the rule"
else
    bad "deny reason: '$reason'"
fi

# Malformed hook input without git/gh text passes silently.
if [ -z "$(printf 'not json' | "$GUARD" 2>/dev/null)" ]; then ok "malformed input without git/gh: no output"; else bad "malformed input produced output"; fi

[ "$fail" = 0 ] && echo "all claude-openrouter-guard tests passed"
exit "$fail"
