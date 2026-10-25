#!/bin/bash
# The squad heavy-slot gate: the PreToolUse Bash hook in settings.exxo.json
# that runs `squad heavy check --hook`. Runs the merged hook command from a
# throwaway claude-sync into a fake $HOME, with a stub `squad` on PATH that
# answers like the real one (the real decision logic is tested in the squad
# repo). Checks: allow, deny passthrough, no $SQUAD_MEMBER, broker down, squad
# missing or too old, and which contexts carry the hook.
# Usage: bash tests/squad-heavy-hook.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"; BIN="$T/bin"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE" "$BIN"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

HOME="$FAKE" "$REPO/scripts/claude-sync" >"$T/sync.log" 2>&1 || { bad "claude-sync exited non-zero"; cat "$T/sync.log"; }
S() { echo "$FAKE/.claude-$1/settings.json"; }
MARK='# squad-heavy-gate'
hook_cmd() { jq -r --arg m "$MARK" '[.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[].command | select(endswith($m))] | first // empty' "$(S "$1")"; }

for ctx in exxo exxo-personal exxo-openrouter; do
    check "$ctx carries the heavy gate" test -n "$(hook_cmd "$ctx")"
done
check "personal has no heavy gate" test -z "$(hook_cmd personal)"
check "shared PreToolUse entries survive in exxo" \
    test "$(jq '.hooks.PreToolUse | length' "$(S exxo)")" -gt 1

CMD="$(hook_cmd exxo)"
INPUT='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"just ci"}}'
DENY='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"heavy job needs a slot"}}'
BASEPATH="/usr/bin:/bin"

# Stub squad: behaviour per $STUB. Like the real command it prints nothing
# unless it denies, and it denies only with $SQUAD_MEMBER set.
cat >"$BIN/squad" <<STUB
#!/bin/bash
[ "\$1 \$2 \$3" = "heavy check --hook" ] || exit 64
cat >/dev/null
case "\${STUB:-allow}" in
    allow) exit 0 ;;
    deny)  [ -n "\${SQUAD_MEMBER:-}" ] && printf '%s\n' '$DENY'; exit 0 ;;
    down)  echo 'WARN squad: broker unreachable; allowing' >&2; exit 0 ;;
    old)   exit 64 ;;
esac
STUB
chmod +x "$BIN/squad"

run() { # run <stub> [VAR=val ...] -> sets OUT, RC
    local stub="$1"; shift
    OUT="$(env -u SQUAD_MEMBER "$@" STUB="$stub" PATH="$BIN:$BASEPATH" /bin/sh -c "$CMD" <<<"$INPUT" 2>/dev/null)"; RC=$?
}

run allow SQUAD_MEMBER=alpha
check "allow: exit 0, no output" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$RC" "$OUT"

run deny SQUAD_MEMBER=alpha
check "deny: exit 0" test "$RC" -eq 0
check "deny: the decision reaches stdout" \
    bash -c 'jq -e ".hookSpecificOutput.permissionDecision == \"deny\"" <<<"$1" >/dev/null' _ "$OUT"

run deny
check "no SQUAD_MEMBER: not blocked" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$RC" "$OUT"

run down SQUAD_MEMBER=alpha
check "broker down: fails open (exit 0, no output)" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$RC" "$OUT"

run old SQUAD_MEMBER=alpha
check "squad too old for 'heavy': exit 0, no output" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$RC" "$OUT"

OUT="$(SQUAD_MEMBER=alpha PATH="$T/empty:/usr/bin:/bin" /bin/sh -c "$CMD" <<<"$INPUT" 2>/dev/null)"; RC=$?
check "squad not installed: exit 0, no output" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$RC" "$OUT"

[ "$fail" = 0 ] && echo "all squad heavy hook tests passed"
exit "$fail"
