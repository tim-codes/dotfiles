#!/bin/bash
# Exercise scripts/ux-designer-peer against stub `tmux` and `claude-kickoff` on
# PATH (no real tmux window or Claude session is ever opened). The template comes
# from UX_DESIGNER_TEMPLATE, so this test does not depend on the skill's wording.
# Usage: bash tests/ux-designer-peer.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PEER="$SRC_REPO/scripts/ux-designer-peer"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"
mkdir -p "$BIN" "$T/app"

cat >"$BIN/tmux" <<'STUB'
#!/bin/bash
echo "$*" >>"$TMUX_LOG"
case "$1" in
display-message) echo main ;;
new-window) echo @7 ;;
esac
STUB
cat >"$BIN/claude-kickoff" <<'STUB'
#!/bin/bash
echo "$*" >>"$KICK_LOG"
exit "${KICK_RC:-0}"
STUB
chmod +x "$BIN/tmux" "$BIN/claude-kickoff"
printf 'S={{SCOPE}} T={{TARGET}} B={{BUILDER}} N={{NAME}} C={{CONTEXT}}\n' >"$T/template.md"

export TMUX_LOG="$T/tmux.log" KICK_LOG="$T/kick.log"
: >"$TMUX_LOG"; : >"$KICK_LOG"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
expect_rc() { local d="$1" want="$2"; if [ "$rc" = "$want" ]; then ok "$d"; else bad "$d (rc=$rc, want $want)"; fi; }

# run <args...>: default env is inside tmux, context personal; sets rc, out, err.
run() {
    out=$(env PATH="$BIN:/usr/bin:/bin" TMUX=x CLAUDE_CONFIG_DIR="$T/.claude-personal" \
        UX_DESIGNER_TEMPLATE="$T/template.md" "$PEER" "$@" 2>"$T/err")
    rc=$?
    err=$(cat "$T/err")
}
# runenv <env assignments...> -- <args...>: same, but with a custom environment.
runenv() {
    local envs=()
    while [ "$1" != -- ]; do envs+=("$1"); shift; done
    shift
    out=$(env -i PATH="$BIN:/usr/bin:/bin" HOME="$T/home" TMUX_LOG="$TMUX_LOG" KICK_LOG="$KICK_LOG" UX_DESIGNER_TEMPLATE="$T/template.md" "${envs[@]}" "$PEER" "$@" 2>"$T/err")
    rc=$?
    err=$(cat "$T/err")
}
newwin() { grep -c '^new-window' "$TMUX_LOG"; }
reset() { : >"$TMUX_LOG"; : >"$KICK_LOG"; rm -rf "$T/briefs"; }

run start --target http://localhost:3000 --scope 'Nav & density (main screen)' --builder builder-1 --cwd "$T/app" --brief-dir "$T/briefs"
check "start_prints_brief_name_window" bash -c 'printf "%s\n" "$1" | grep -qx "name: ux-designer-nav-density-main-screen" && printf "%s\n" "$1" | grep -qx "window: @7" && printf "%s\n" "$1" | grep -q "^brief: $2/briefs/[0-9]\{6\}-[0-9]\{6\}-nav-density-main-screen\.md$"' _ "$out" "$T"
brief=$(printf '%s\n' "$out" | sed -n 's/^brief: //p')
check "brief_frontmatter_exact" test "$(sed -n 1,8p "$brief" | tr '\n' '|')" = "---|cwd: $T/app|context: personal|model: opus|effort: high|agent: ux-designer|name: ux-designer-nav-density-main-screen|---|"
check "brief_body_substituted" grep -qxF "S=Nav & density (main screen) T=http://localhost:3000 B=builder-1 N=ux-designer-nav-density-main-screen C=personal" "$brief"
check "kickoff_dry_run_validated_brief" grep -qxF "$brief --dry-run" "$T/kick.log"
check "tmux_new_window_argv" grep -qxF "new-window -d -P -F #{window_id} -t main: -n ux-designer -c $T/app claude-kickoff $brief" "$T/tmux.log"

# scope_metacharacters_survive
reset
scope=$'a "q" $HOME `x` & \\1\n---\nz'
run start --target https://x.test/ --scope "$scope" --builder b --cwd "$T/app" --brief-dir "$T/briefs"
brief=$(printf '%s\n' "$out" | sed -n 's/^brief: //p')
printf 'S=%s T=https://x.test/ B=b N=ux-designer-a-q-home-x-1-z C=personal\n' "$scope" >"$T/expected-body"
check "scope_metacharacters_survive_body" bash -c 'tail -n +9 "$1" | cmp -s - "$2"' _ "$brief" "$T/expected-body"
check "scope_metacharacters_survive_frontmatter" test "$(sed -n 1,8p "$brief" | tr '\n' '|')" = "---|cwd: $T/app|context: personal|model: opus|effort: high|agent: ux-designer|name: ux-designer-a-q-home-x-1-z|---|"
check "scope_metacharacters_survive_slug" grep -qx "name: ux-designer-a-q-home-x-1-z" <<<"$out"

# model_override
reset
run start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs" --model sonnet --effort low
brief=$(printf '%s\n' "$out" | sed -n 's/^brief: //p')
check "model_override_model" grep -qx "model: sonnet" "$brief"
check "model_override_effort" grep -qx "effort: low" "$brief"

# context_flag_wins
reset
run start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs" --context reserve
brief=$(printf '%s\n' "$out" | sed -n 's/^brief: //p')
check "context_flag_wins" grep -qx "context: reserve" "$brief"

# refuses_outside_tmux
reset
runenv CLAUDE_CONFIG_DIR="$T/.claude-personal" -- start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs"
expect_rc "refuses_outside_tmux_rc" 3
check "refuses_outside_tmux_no_window" test "$(newwin)" = 0
check "refuses_outside_tmux_no_brief" test ! -e "$T/briefs"

# session_flag_outside_tmux
reset
runenv CLAUDE_CONFIG_DIR="$T/.claude-personal" -- start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs" --session work
expect_rc "session_flag_outside_tmux_rc" 0
check "session_flag_outside_tmux_target" grep -q -- ' -t work: ' "$TMUX_LOG"

# refuses_without_context
reset
runenv TMUX=x -- start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs"
expect_rc "refuses_without_context" 3

# refuses_bad_target
reset
run start --target localhost:3000 --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs"
expect_rc "refuses_bad_target" 2

# missing_builder_exits_2
reset
run start --target http://h/ --scope s --cwd "$T/app" --brief-dir "$T/briefs"
expect_rc "missing_builder_exits_2" 2

# kickoff_refusal_exits_4
reset
KICK_RC=4 run start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs"
expect_rc "kickoff_refusal_exits_4_rc" 4
check "kickoff_refusal_exits_4_no_window" test "$(newwin)" = 0

# dry_run_runs_no_tmux_new_window
reset
run start --target http://h/ --scope s --builder b --cwd "$T/app" --brief-dir "$T/briefs" --dry-run
expect_rc "dry_run_rc" 0
check "dry_run_tmux_line" grep -q '^tmux: ' <<<"$out"
check "dry_run_no_window_line" bash -c '! printf "%s\n" "$1" | grep -q "^window: "' _ "$out"
check "dry_run_no_new_window" test "$(newwin)" = 0
check "dry_run_kickoff_ran" grep -q -- '--dry-run' "$T/kick.log"

# stop_kills_by_id
reset
run stop @7
expect_rc "stop_kills_by_id_rc" 0
check "stop_kills_by_id_log" test "$(tail -n 1 "$TMUX_LOG")" = "kill-window -t @7"
check "stop_kills_by_id_out" test "$out" = "closed: @7"

# stop_refuses_non_window_id
reset
for a in main ux-designer '' '@7;x' 'main:1'; do
    run stop "$a"
    expect_rc "stop_refuses_non_window_id[$a]" 2
done
check "stop_refuses_non_window_id_log_unchanged" test ! -s "$TMUX_LOG"

check "never_kill_session" bash -c '! grep -q kill-session "$1"' _ "$PEER"

exit "$fail"
