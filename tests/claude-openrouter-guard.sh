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
# Review round 1 (R-C9) fixtures: push targets that come from repo config.
#   pushcfg-clone: on job/x with remote.origin.push=HEAD:main
#   upstream-clone: on job/y tracking origin/main, push.default=upstream
#   matching-clone: on job/x with push.default=matching
#   alias-clone: on job/x with alias.p = "push origin main"
for c in pushcfg upstream matching alias; do g clone -q -b job/x "$T/origin.git" "$T/$c-clone"; done
g -C "$T/pushcfg-clone" config remote.origin.push HEAD:main
g -C "$T/upstream-clone" checkout -q -b job/y --track origin/main
g -C "$T/upstream-clone" config push.default upstream
g -C "$T/matching-clone" config push.default matching
g -C "$T/alias-clone" config alias.p "push origin main"
# glob-clone: files that make an unquoted glob expand to a merge word.
g clone -q -b job/x "$T/origin.git" "$T/glob-clone"
mkdir -p "$T/glob-clone/repos/o/r/pulls/1"; touch "$T/glob-clone/merge" "$T/glob-clone/repos/o/r/pulls/1/merge"
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

# expect <deny|allow> <cwd-key> <command>; cwd-key names a <key>-clone fixture
expect() {
    local want="$1" key="$2" cmd="$3" got
    got="$(run_guard "$T/$key-clone" "$cmd")"
    local shown="${cmd//$'\n'/\\n}"
    if [ "$got" = "$want" ]; then ok "$want [$key] $shown"; else bad "want $want, got $got [$key] $shown"; fi
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

# --- BLOCK: review round 1 findings (R-C9) --------------------------------
while IFS='|' read -r key cmd; do
    [ -z "$key" ] && continue
    expect deny "$key" "$cmd"
done <<'TABLE'
job|echo 'git push origin main' | bash
job|printf 'gh pr merge 1' | sh
job|bash <<< 'gh pr merge 1'
job|bash -c -- 'gh pr merge 1'
job|bash -c -e 'git push origin main'
job|fish -c 'gh pr merge 1'
job|$'git' push origin main
job|G=git; $G push origin main
job|${NOPE}gh pr merge 1
job|git -c remote.origin.push=HEAD:main push origin
job|GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.push GIT_CONFIG_VALUE_0=HEAD:main git push origin
job|GIT_DIR=../main-clone/.git git push
pushcfg|git push
pushcfg|git push origin
pushcfg|git push origin job/x
upstream|git push
matching|git push
alias|git p
job|git push origin HEAD:heads/main
job|git push origin job/x:heads/master
job|git push origin HEAD:MAIN
job|true;>x gh pr merge 1
job|true&&>/dev/null git push origin main
job|function f { gh pr merge 1; }; f
job|f() { gh pr merge 1; }; f
job|env -S 'git push origin main'
job|xcrun git push origin main
job|arch -arm64 git push origin main
job|caffeinate -i gh pr merge 1
job|find . -exec gh pr merge 1 \;
job|cat <(gh pr merge 1)
job|gh api repos/o/r/merges -f base=main -f head=job/x
job|gh api -X PATCH repos/o/r/git/refs/heads/main -f sha=abc123
job|gh api graphql -f query='mutation { enablePullRequestAutoMerge(input:{pullRequestId:"x"}) { clientMutationId } }'
job|gh api graphql -f query='mutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }'
job|gh api graphql --input body.json
job|gh api -X PUT repos/o/r/contents/f.txt -f message=m -f content=eA==
job|gh api -X PUT repos/o/r/contents/f.txt -f message=m -f content=eA== -f branch=main
job|gh alias set m 'pr merge'
job|gh m 1
job|g""it pu""sh origin main
job|git send-pack ../../origin.git HEAD:refs/heads/main
job|git submodule foreach 'git push origin main'
job|git rebase -x 'git push origin main' HEAD
job|git config alias.p 'push origin main'
job|git push --receive-pack=x origin job/x
job|./git push origin job/x
job|git commit -m "$(cat msg)" && git push origin job/x
job|export GIT_DIR=../main-clone/.git; git push
job|alias g=git; g push origin main
job|python3 -c 'import os; os.system("git push origin main")'
TABLE

# --- BLOCK: review round 2 findings ----------------------------------------
while IFS='|' read -r key cmd; do
    [ -z "$key" ] && continue
    expect deny "$key" "$cmd"
done <<'TABLE'
job|true x#; git push origin HEAD:main
job|git push origin job/x#; gh pr merge 1
job|git push origin HEAD:{main,job/x}
job|gh pr {merge,} 1
job|gh pr {me,}rge 1
job|gh api repos/o/r/pulls/1/{merge,}
job|git pu{s,}h origin HEAD:main
job|touch HEAD:main; git push origin HEAD:mai?
job|gh api -X PATCH repos/{owner}/{repo}/git/refs/heads/{branch} -f sha=abc
glob|gh api repos/o/r/pulls/1/mer?e
glob|gh pr mer?e 1
glob|gh pr [m]erge 1
job|git push origin #job/x
job|git push origin HEAD:main # comment
job|git push origin HEAD:ma[i]n
job|gh workflow run merge.yml
job|gh workflow run deploy.yml --ref job/x
job|gh run rerun 123
job|gh api -X POST repos/o/r/actions/workflows/merge.yml/dispatches -f ref=job/x
job|gh api repos/o/r/dispatches -f event_type=merge
TABLE

expect deny job "$(printf 'git push origin HEAD:ma\\\nin')"
expect deny job "$(printf 'gh pr mer\\\nge 1')"
expect deny job "$(printf 'git pu\\\nsh origin HEAD:main')"

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
job|cargo test
job|ls
job|gh run list
job|git commit -m "fix: x"
job|gh pr create --draft --body "$(cat body.md)"
job|gh api -X PUT repos/o/r/contents/f.txt -f message=m -f content=eA== -f branch=job/x
job|gh api repos/o/r/contents/README.md
job|cargo test && git push origin job/x
job|git rebase main
job|gh run list --workflow ci.yml
job|gh pr mer?e 1
job|gh api repos/{owner}/{repo}/pulls
job|gh api 'repos/o/r/pulls?state=all'
job|{ git status; }
job|git log --oneline # recent
job|gh pr view 1 --json title -q '.title'
job|gh workflow list
job|git log --grep='[Ff]ix'
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
    '.rule == "unparseable" and .target == null and .form == "sh-c" and .decision == "block"'
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

# I3: a FIFO at the log path must not hang the hook (a hook timeout fails open).
rm -f "$L"; mkfifo "$L"
( run_guard "$T/job-clone" "gh pr merge 1" >"$T/fifo.out" ) & pid=$!
for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null; pkill -f claude-openrouter-guard 2>/dev/null
    bad "fifo_log_path_still_blocks: guard hung on a FIFO log path"
elif [ "$(cat "$T/fifo.out")" = deny ]; then
    ok "fifo_log_path_still_blocks"
else
    bad "fifo_log_path_still_blocks: got $(cat "$T/fifo.out")"
fi
rm -f "$L"

# M1: malformed tool_input on a Bash call fails closed.
for ti in '"gh pr merge 1"' '["gh pr merge 1"]' '{"command":["git","push","origin","main"]}' 'null'; do
    out="$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":%s}' "$T/job-clone" "$ti" | "$GUARD" 2>/dev/null)"; rc=$?
    if [ "$rc" = 0 ] && jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$out" >/dev/null 2>&1; then
        ok "malformed tool_input denied: $ti"
    else
        bad "malformed tool_input not denied (rc=$rc): $ti"
    fi
done

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
