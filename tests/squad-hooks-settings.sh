#!/bin/bash
# Squad v0.5 hook, MCP and grant wiring: runs claude-sync into a throwaway repo
# copy and a fake $HOME (never the real contexts) and checks that every context
# carries the squad hook handlers of contracts/README.md rule 8 (byte for byte,
# so Claude Code runs one when the broker also passes them with --settings),
# the `squad` stdio MCP server and the v0.5 grants, that the handler commands
# fail open, and that the member deny overlay stays the six merge rules.
# Usage: bash tests/squad-hooks-settings.sh
#   SQUAD_CONTRACTS_DIR   directory holding the squad repo's contracts/README.md
#                         (else read it from git in $SQUAD_REPO at
#                         $SQUAD_CONTRACTS_REF)
#   SQUAD_CONTRACTS_REQUIRED=1   turn the byte-for-byte skip into a failure
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"; BIN="$T/bin"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE" "$BIN" "$T/empty"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
CTXS=(personal reserve exxo exxo-personal exxo-openrouter)
for c in "${CTXS[@]}"; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()   { printf 'ok:   %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*"; fail=1; }
skip() { printf 'skip: %s\n' "$*"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

HOME="$FAKE" "$REPO/scripts/claude-sync" >"$T/sync.log" 2>&1 || { bad "claude-sync exited non-zero"; cat "$T/sync.log"; }
S() { echo "$FAKE/.claude-$1/settings.json"; }
J() { echo "$FAKE/.claude-$1/.claude.json"; }

# The handler objects rule 8 pins: <event>|<matcher or empty>|<cli arg>|<timeout>.
ROWS=(
    'SessionStart||session-start|10'
    'Stop||stop|10'
    'UserPromptSubmit||user-prompt-submit|10'
    'PreToolUse|Bash|pre-tool-use|10'
    'PermissionRequest||permission-request|10'
    'PostToolUse||prompt-cleared|10'
    'PostToolUseFailure||prompt-cleared|10'
    'PermissionDenied||prompt-cleared|10'
    'SessionEnd||session-end|5'
)
# Command string, built from the pieces so it is written once here: the guard
# and stdout capture are what keep a v0.4 `squad` (exit 2 on `hook`) or a missing
# binary from blocking anything.
cmd_for() { printf 'command -v squad >/dev/null 2>&1 && o=$(squad hook %s) && printf '"'"'%%s\\n'"'"' "$o"; exit 0' "$1"; }
entry_for() { # <matcher> <arg> <timeout>
    jq -cn --arg m "$1" --arg c "$(cmd_for "$2")" --argjson t "$3" \
        '(if $m == "" then {} else {matcher: $m} end) + {hooks: [{type: "command", command: $c, timeout: $t}]}'
}

for ctx in "${CTXS[@]}"; do
    for row in "${ROWS[@]}"; do
        IFS='|' read -r ev matcher arg to <<<"$row"
        want="$(entry_for "$matcher" "$arg" "$to")"
        n="$(jq --argjson w "$want" --arg e "$ev" '[.hooks[$e][]? | select(. == $w)] | length' "$(S "$ctx")")"
        check "$ctx: $ev carries the squad handler once" test "$n" = 1
    done
    check "$ctx: no v0.4 squad hook remains" \
        jq -e '[.hooks[][]?.hooks[]?.command | select(contains("squad-prompt-hook") or contains("squad heavy check") or contains("# squad-heavy-gate"))] | length == 0' "$(S "$ctx")"
    check "$ctx: other tools' hooks survive" \
        jq -e '[.hooks.Stop[]?.hooks[]?.command | select(contains("tmux-home"))] | length >= 1' "$(S "$ctx")"
    check "$ctx: squad MCP server is the P1 entry" \
        jq -e '.mcpServers.squad == {"type":"stdio","command":"squad","args":["mcp"]}' "$(J "$ctx")"
    check "$ctx: other managed MCP servers survive" \
        jq -e '.mcpServers.mantine.type == "stdio" and .mcpServers.datadog.type == "http"' "$(J "$ctx")"
    check "$ctx: does not deny the squad server" \
        jq -e '[(.deniedMcpServers // [])[] | select(.serverName == "squad")] | length == 0' "$(S "$ctx")"
    for t in register set ack delegate delegate_result job_review raise watch unwatch heavy_slot land; do
        check "$ctx: grants mcp__squad__$t" \
            jq -e --arg r "mcp__squad__$t" '.permissions.allow | index($r) != null' "$(S "$ctx")"
    done
    check "$ctx: grants no submit_task and no squad wildcard" \
        jq -e '[.permissions.allow[] | select(. == "mcp__squad__submit_task" or . == "mcp__squad__*")] | length == 0' "$(S "$ctx")"
    for r in 'Bash(squad status:*)' 'Bash(squad doctor:*)' 'Bash(squad debug report:*)'; do
        check "$ctx: keeps $r" jq -e --arg r "$r" '.permissions.allow | index($r) != null' "$(S "$ctx")"
    done
    check "$ctx: no v0.4 squad CLI grant" jq -e '[.permissions.allow[] | select(IN(
        "Bash(squad send:*)","Bash(squad set:*)","Bash(squad publish:*)","Bash(squad subscribe:*)",
        "Bash(squad unsubscribe:*)","Bash(squad register:*)","Bash(squad deregister:*)","Bash(squad roster:*)",
        "Bash(squad get:*)","Bash(squad history:*)","Bash(squad debug:*)","Bash(squad operator raise:*)",
        "Bash(squad operator set:*)","Bash(squad operator decide:*)","Bash(squad operator list:*)",
        "Bash(squad operator get:*)","Bash(squad ack:*)"))] | length == 0' "$(S "$ctx")"
done

# Rule 8 byte for byte: extract the pinned handler objects from the squad
# repo's contracts/README.md and compare each, whole, with the merged entry.
README="$T/contracts-README.md"
if [ -n "${SQUAD_CONTRACTS_DIR:-}" ] && [ -r "$SQUAD_CONTRACTS_DIR/README.md" ]; then
    cp "$SQUAD_CONTRACTS_DIR/README.md" "$README"
elif git -C "${SQUAD_REPO:-$HOME/dev/squad}" show "${SQUAD_CONTRACTS_REF:-origin/trunk/v0.5}:contracts/README.md" >"$README" 2>/dev/null; then
    :
else
    rm -f "$README"
fi
if [ -r "$README" ]; then
    awk '/^## 8\. /{f=1;next} /^## 9\. /{f=0} f&&/^```json/{j=1;next} f&&j&&/^```/{exit} f&&j' "$README" >"$T/rule8.json"
    if jq -e '.hooks | length >= 9' "$T/rule8.json" >/dev/null 2>&1; then
        for row in "${ROWS[@]}"; do
            IFS='|' read -r ev _ _ _ <<<"$row"
            check "hook handler equals contracts rule 8 byte for byte: $ev" \
                jq -e --slurpfile r "$T/rule8.json" --arg e "$ev" \
                '$r[0].hooks[$e] as $w | ($w | length) == 1 and ([.hooks[$e][] | select(. == $w[0])] | length) == 1' "$(S exxo)"
        done
    else
        bad "hook handlers equal contracts rule 8: README rule 8 carries no pinned handler JSON (pre-amendment contracts?)"
    fi
elif [ "${SQUAD_CONTRACTS_REQUIRED:-}" = 1 ]; then
    bad "hook handlers equal contracts rule 8: no contracts source readable"
else
    skip "hook handlers equal contracts rule 8: no contracts source readable (set SQUAD_CONTRACTS_DIR)"
fi

check "member deny file is the six merge rules only" \
    jq -e 'keys == ["permissions"] and (.permissions | keys == ["deny"]) and .permissions.deny == ["Bash(gh pr merge*)","Bash(* gh pr merge*)","Bash(gh * pr merge*)","Bash(* gh * pr merge*)","Bash(gh api *merge*)","Bash(* gh api *merge*)"]' \
    "$SRC_REPO/files/claude/settings.member-deny.json"
for ctx in personal reserve exxo exxo-personal; do
    check "$ctx: member deny is not merged" \
        jq -e '[.permissions.deny[] | select(. == "Bash(gh * pr merge*)")] | length == 0' "$(S "$ctx")"
done

# The handler commands themselves, run as Claude Code runs them.
mapfile -t CMDS < <(jq -r '[.hooks[][]?.hooks[]?.command | select(contains("squad hook"))] | unique[]' "$(S exxo)")
check "seven distinct squad hook commands in the merged exxo settings" test "${#CMDS[@]}" -eq 7
INPUT='{"session_id":"00000000-0000-4000-8000-000000000000","hook_event_name":"X"}'
cat >"$BIN/squad" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >"$T/argv"
cat >"$T/stdin"
printf '%s\n' '{"stub":true}'
STUB
chmod +x "$BIN/squad"
for c in "${CMDS[@]}"; do
    arg="$(sed -E 's/.*squad hook ([a-z-]+)\).*/\1/' <<<"$c")"
    rm -f "$T/argv" "$T/stdin"
    out="$(PATH="$BIN:/usr/bin:/bin" /bin/sh -c "$c" <<<"$INPUT" 2>/dev/null)"; rc=$?
    check "hook command passes stdin and stdout through: $arg" \
        bash -c '[ "$1" -eq 0 ] && [ "$2" = "{\"stub\":true}" ] && [ "$(cat "$3")" = "hook $4" ] && [ "$(cat "$5")" = "$6" ]' \
        _ "$rc" "$out" "$T/argv" "$arg" "$T/stdin" "$INPUT"
done
for c in "${CMDS[@]}"; do
    arg="$(sed -E 's/.*squad hook ([a-z-]+)\).*/\1/' <<<"$c")"
    out="$(PATH="$T/empty:/usr/bin:/bin" /bin/sh -c "$c" <<<"$INPUT" 2>/dev/null)"; rc=$?
    check "squad missing: $arg exits 0 with empty stdout" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$rc" "$out"
done
cat >"$BIN/squad" <<'STUB'
#!/bin/bash
echo "error: unrecognized subcommand 'hook'"
echo "error: unrecognized subcommand 'hook'" >&2
exit 2
STUB
for c in "${CMDS[@]}"; do
    arg="$(sed -E 's/.*squad hook ([a-z-]+)\).*/\1/' <<<"$c")"
    out="$(PATH="$BIN:/usr/bin:/bin" /bin/sh -c "$c" <<<"$INPUT" 2>/dev/null)"; rc=$?
    check "v0.4 squad exiting 2: $arg exits 0 with empty stdout" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$rc" "$out"
done

[ "$fail" = 0 ] && echo "all squad hook settings tests passed"
exit "$fail"
