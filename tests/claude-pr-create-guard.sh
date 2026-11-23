#!/bin/bash
# Table-driven tests for scripts/claude-pr-create-guard, the PreToolUse hook
# (Bash) that denies standalone work on gaia/* refs and asks before a second
# claude/* PR to the same base. A fake `gh` on PATH answers from fixture files
# and logs every call; temp git repos give the cwd's remote, origin/HEAD and
# current branch. Nothing is pushed and no PR is created: the guard only parses.
# Also checks the wiring: the hook sits in settings.shared.json only (the user
# settings standalone sessions load), never in another fragment.
# Usage: bash tests/claude-pr-create-guard.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$SRC_REPO/scripts/claude-pr-create-guard"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$T/bin"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

g() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@" >/dev/null 2>&1; }

# repo: on claude/topic, origin is a GitHub URL, origin/HEAD -> main.
# gaia-repo: same remote, checked out on gaia/task-7.
g init -q -b main "$T/repo"
g -C "$T/repo" commit -q --allow-empty -m init
g -C "$T/repo" remote add origin git@github.com:acme/widgets.git
g -C "$T/repo" update-ref refs/remotes/origin/main HEAD
g -C "$T/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
g -C "$T/repo" checkout -q -b claude/topic
g clone -q "$T/repo" "$T/gaia-repo"
g -C "$T/gaia-repo" remote set-url origin git@github.com:acme/widgets.git
g -C "$T/gaia-repo" checkout -q -b gaia/task-7
mkdir -p "$T/repo/sub"

# Fake gh: logs argv; `pr list` prints $FAKE_GH_PRS (a file) filtered by
# --base against each entry's baseRefName; `repo view` prints $FAKE_GH_DEFAULT.
# FAKE_GH_MODE=fail exits 1, =slow sleeps past the guard's timeout.
cat >"$T/bin/gh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
case "${FAKE_GH_MODE:-}" in fail) exit 1 ;; slow) sleep 5; exit 0 ;; esac
if [ "$1 $2" = "pr list" ]; then
    base=""; prev=""
    for a in "$@"; do [ "$prev" = --base ] && base="$a"; prev="$a"; done
    jq -c --arg b "$base" '[.[] | select(.baseRefName == $b) | {number, title, headRefName}]' "$FAKE_GH_PRS"
elif [ "$1 $2" = "repo view" ]; then
    echo "${FAKE_GH_DEFAULT:-main}"
fi
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh.log" FAKE_GH_PRS="$T/prs.json"

cat >"$T/prs.json" <<'EOF'
[
  {"number": 11, "title": "Fix the widget", "headRefName": "claude/widget-fix", "baseRefName": "main"},
  {"number": 12, "title": "Docs pass", "headRefName": "claude/docs", "baseRefName": "main"},
  {"number": 13, "title": "Tim's own", "headRefName": "tim/manual", "baseRefName": "main"},
  {"number": 14, "title": "Same head", "headRefName": "claude/topic", "baseRefName": "main"},
  {"number": 15, "title": "Other base", "headRefName": "tim/release-prep", "baseRefName": "release"}
]
EOF
echo '[]' >"$T/none.json"

# run_guard <cwd> <command> [tool] -> prints deny | ask | silent | invalid
run_guard() {
    local out
    out="$(jq -n --arg c "$2" --arg d "$1" --arg t "${3:-Bash}" \
        '{session_id:"s", cwd:$d, hook_event_name:"PreToolUse", tool_name:$t, tool_input:{command:$c}}' \
        | "$GUARD" 2>"$T/stderr")"
    printf '%s' "$out" >"$T/last"
    if [ -z "$out" ]; then echo silent
    else jq -r '.hookSpecificOutput.permissionDecision // "invalid"' <<<"$out" 2>/dev/null || echo invalid
    fi
}
expect() { # <want> <cwd> <command> [description]
    : >"$FAKE_GH_LOG"
    local got; got="$(run_guard "$2" "$3")"
    if [ "$got" = "$1" ]; then ok "${4:-$3} -> $1"; else bad "${4:-$3}: want $1, got $got ($(cat "$T/last"))"; fi
}
gh_calls() { [ -s "$FAKE_GH_LOG" ] && wc -l <"$FAKE_GH_LOG" | tr -d ' ' || echo 0; }

R="$T/repo"; G="$T/gaia-repo"

echo "# deny: gaia/* refs"
expect deny "$R" 'gh pr create --base gaia/trunk-x --title t --body b'
expect deny "$R" 'gh pr create -B gaia/trunk-x -t t'
expect deny "$R" 'gh pr create --base=gaia/trunk-x'
expect deny "$R" 'gh pr create -Bgaia/trunk-x'
expect deny "$R" 'gh pr create --head gaia/leader-fix --base main'
expect deny "$R" 'gh pr create -H acme:gaia/leader-fix'
expect deny "$G" 'gh pr create --base main --fill' 'pr create from a gaia/* current branch'
expect deny "$R" 'git push origin HEAD:gaia/leader-x'
expect deny "$R" 'git push origin claude/topic:refs/heads/gaia/trunk-1'
expect deny "$R" 'git push -u origin gaia/task-9'
expect deny "$R" 'git push origin +HEAD:gaia/x'
expect deny "$R" "git -C $G push" 'bare push on a gaia/* branch (git -C)'
expect deny "$R" "cd $G && git push origin HEAD" 'push HEAD after cd onto a gaia/* branch'
expect deny "$R" 'git status && gh pr create --base gaia/t' 'second command of a list'
expect deny "$R" 'FOO=1 agent/run -- gh pr create --base gaia/t' 'behind env and agent/run'
expect deny "$R" 'gh pr create --title "x" --base gaia/t | cat'
: >"$FAKE_GH_LOG"; run_guard "$R" 'gh pr create --base gaia/t' >/dev/null
reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' "$T/last")"
case "$reason" in *"gaia/* belongs to Gaia"*"role: orchestrator"*branches-and-prs.md*) ok "deny reason names the convention" ;; *) bad "deny reason: $reason" ;; esac
[ "$(gh_calls)" = 0 ] && ok "deny makes no gh call" || bad "deny made gh calls: $(cat "$FAKE_GH_LOG")"

echo "# ask: open claude/* PRs to the same base"
expect ask "$R" 'gh pr create --base main --title t --body b'
reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' "$T/last")"
case "$reason" in
    *"2 open PRs against \`main\` in acme/widgets"*'#11 "Fix the widget" (claude/widget-fix)'*'#12 "Docs pass" (claude/docs)'*"Combine this into one of them, or continue with a separate PR?"*)
        ok "ask lists the PRs and both options" ;;
    *) bad "ask reason: $reason" ;;
esac
case "$reason" in *'#13'*|*'#14'*|*'#15'*) bad "ask lists a non-claude, same-head or other-base PR: $reason" ;; *) ok "ask leaves out non-claude/*, same-head and other-base PRs" ;; esac
[ "$(gh_calls)" = 1 ] && ok "ask: exactly one gh call" || bad "ask: gh calls: $(cat "$FAKE_GH_LOG")"
grep -q -- 'pr list -R acme/widgets --author @me --state open --base main' "$FAKE_GH_LOG" \
    && ok "pr list targets the cwd's repo, base and @me" || bad "pr list args: $(cat "$FAKE_GH_LOG")"
expect ask "$R" 'gh pr create --fill' 'base from origin/HEAD'
expect ask "$R/sub" 'gh pr create --fill' 'cwd in a subdirectory'
expect ask "$R" 'gh pr create -R acme/widgets --fill' '-R matching the cwd remote'
expect ask "$T" 'gh pr create -R acme/gadgets --fill' '-R elsewhere: base from gh repo view'
grep -q 'repo view acme/gadgets' "$FAKE_GH_LOG" && ok "-R elsewhere looks up the default branch" || bad "no repo view: $(cat "$FAKE_GH_LOG")"
grep -q 'pr list -R acme/gadgets' "$FAKE_GH_LOG" && ok "-R elsewhere lists that repo's PRs" || bad "pr list repo: $(cat "$FAKE_GH_LOG")"
expect ask "$R" 'gh pr create -R https://github.com/acme/widgets --fill' '-R as a URL'

echo "# silent"
expect silent "$R" 'gh pr create --base release --title t' 'different base: claude/* PRs on main do not count'
FAKE_GH_PRS="$T/none.json" expect silent "$R" 'gh pr create --base main --fill' 'no open PRs'
expect silent "$R" 'echo "gh pr create --base gaia/x"' 'quoted text in echo'
expect silent "$R" "printf '%s' 'git push origin HEAD:gaia/x'" 'quoted push in printf'
expect silent "$R" 'git commit -m "gh pr create --base gaia/x"' 'quoted text in a commit message'
expect silent "$R" 'gh pr list --base gaia/trunk-1' 'pr list is not pr create'
expect silent "$R" 'gh pr view 12' 'pr view'
[ "$(gh_calls)" = 0 ] && ok "non-create gh command makes no gh call" || bad "gh called: $(cat "$FAKE_GH_LOG")"
expect silent "$R" 'git push origin claude/topic' 'push to claude/*'
expect silent "$R" 'git push' 'bare push on claude/*'
expect silent "$R" 'git status' 'not a pr-create command'
[ "$(gh_calls)" = 0 ] && ok "git command makes no gh call" || bad "gh called: $(cat "$FAKE_GH_LOG")"
expect silent "$R" 'ls -la' 'unrelated command'
: >"$FAKE_GH_LOG"
[ "$(run_guard "$R" 'gh pr create --base gaia/x' Write)" = silent ] && ok "non-Bash tool -> silent" || bad "non-Bash tool not silent"

echo "# fail open"
FAKE_GH_MODE=fail expect silent "$R" 'gh pr create --base main --fill' 'gh exits non-zero'
FAKE_GH_MODE=slow CLAUDE_PR_GUARD_TIMEOUT_S=1 expect silent "$R" 'gh pr create --base main --fill' 'gh times out'
mkdir -p "$T/nogh"
for t in python3 git jq; do ln -sf "$(command -v "$t")" "$T/nogh/$t"; done
PATH="$T/nogh:/usr/bin:/bin" expect silent "$R" 'gh pr create --base main --fill' 'gh missing from PATH'
expect silent "$T" 'gh pr create --base main --fill' 'cwd with no repo and no -R'
expect silent "$R" 'gh pr create --title "unbalanced' 'unparseable command'
out="$(printf 'not json' | "$GUARD")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "invalid stdin -> exit 0, no output" || bad "invalid stdin: rc=$rc out=$out"
printf '[]\n' >"$T/bad.json"
FAKE_GH_PRS="$T/bad.json" expect silent "$R" 'gh pr create --base main --fill' 'empty listing'

echo "# wiring: standalone settings fragment only"
C="$SRC_REPO/files/claude"
n="$(jq '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("scripts/claude-pr-create-guard"))] | length' "$C/settings.shared.json")"
[ "$n" = 1 ] && ok "settings.shared.json wires the guard once on Bash" || bad "settings.shared.json wiring count: $n"
jq -e '[.hooks.PreToolUse[] | .hooks[] | select(.command | contains("claude-pr-create-guard")) | .command | endswith("# claude-pr-create-guard")] | all' "$C/settings.shared.json" >/dev/null \
    && ok "guard command carries its # claude-pr-create-guard tag" || bad "guard tag missing"
for f in "$C"/settings.*.json; do
    [ "$(basename "$f")" = settings.shared.json ] && continue
    grep -q claude-pr-create-guard "$f" && bad "$(basename "$f") also wires the guard" || ok "$(basename "$f") does not wire the guard"
done
for f in $(git -C "$SRC_REPO" ls-files 'src/.config/squad' 'files/claude/plugins'); do
    grep -q claude-pr-create-guard "$SRC_REPO/$f" && bad "$f (Gaia-side or plugin config) wires the guard"
done
ok "no Gaia-side or plugin config in this repo wires the guard"

[ "$fail" = 0 ] && echo "all claude-pr-create-guard tests passed"
exit "$fail"
