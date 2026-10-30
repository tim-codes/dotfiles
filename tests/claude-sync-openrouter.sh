#!/bin/bash
# Exercise claude-sync's exxo-openrouter context against a throwaway repo copy
# and a fake $HOME — never the real contexts and never the real key file
# (same isolation as claude-sync-permissions.sh). The context is built from
# the exxo fragments plus files/claude/settings.overlay.exxo-openrouter.json.
# Usage: bash tests/claude-sync-openrouter.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"; FAKE2="$T/home2"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE" "$FAKE2"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done
mkdir -p "$FAKE2/.claude-exxo" "$FAKE2/.claude-exxo-openrouter/plugins"
C="$REPO/files/claude"
OR="$FAKE/.claude-exxo-openrouter"
S() { echo "$FAKE/.claude-$1/settings.json"; }

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }
has() { jq -e --arg r "$3" ".permissions.$2 | index([\$r]) != null" "$(S "$1")" >/dev/null; }
jqeq() { [ "$(jq -r "$2" "$(S "$1")")" = "$3" ]; }

# Worker deny rules (exact strings). Keys rules cover the three spellings of
# the home directory in plain and "* "-prefixed forms.
WORKER_DENY=(
    'Bash(gh pr merge*)' 'Bash(* gh pr merge*)' 'Bash(*gh api*/merge*)'
    'Bash(git push*main*)' 'Bash(* git push*main*)'
    'Bash(git push*master*)' 'Bash(* git push*master*)'
    'Bash(*agent/run*)' 'Bash(*agent-run*)'
    'Bash(squad mail:*)'
    'Bash(esc)' 'Bash(esc *)' 'Bash(* esc *)'
    'Bash(pulumi up*)' 'Bash(* pulumi up*)'
    'Bash(pulumi env open*)' 'Bash(* pulumi env open*)'
    'Bash(op)' 'Bash(op *)' 'Bash(* op *)'
    'Read(~/keys/**)'
)
for cmd in cat head less grep cp; do
    for sp in '~/keys' '$HOME/keys' '/Users/*/keys'; do
        WORKER_DENY+=("Bash($cmd *$sp*)" "Bash(* $cmd *$sp*)")
    done
done

sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }

check "ANTHROPIC_BASE_URL is OpenRouter" jqeq exxo-openrouter '.env.ANTHROPIC_BASE_URL' 'https://openrouter.ai/api'
check "ANTHROPIC_API_KEY present and empty" \
    jq -e '.env | has("ANTHROPIC_API_KEY") and .ANTHROPIC_API_KEY == ""' "$(S exxo-openrouter)" >/dev/null
for v in ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
         ANTHROPIC_DEFAULT_FABLE_MODEL CLAUDE_CODE_SUBAGENT_MODEL; do
    check "$v is moonshotai/kimi-k3@preset/tim-k3" jqeq exxo-openrouter ".env.$v" 'moonshotai/kimi-k3@preset/tim-k3'
done
check "ENABLE_TOOL_SEARCH is false" jqeq exxo-openrouter '.env.ENABLE_TOOL_SEARCH' 'false'
check "model pinned to sonnet" jqeq exxo-openrouter '.model' 'sonnet'
check "apiKeyHelper names the helper, holds no key" \
    jq -e '.apiKeyHelper | type == "string" and length > 0 and contains("claude-openrouter-key") and (contains("sk-") | not)' \
        "$(S exxo-openrouter)" >/dev/null
check "overlay file holds no literal key" bash -c "! grep -q 'sk-or-' '$C/settings.overlay.exxo-openrouter.json'"

# Deny floor: exxo deny + listed rules not already in the exxo set.
exxo_deny="$(jq '.permissions.deny | length' "$(S exxo)")"
extra=0
for r in "${WORKER_DENY[@]}"; do has exxo deny "$r" || extra=$((extra + 1)); done
for r in "${WORKER_DENY[@]}"; do
    check "worker deny present: $r" has exxo-openrouter deny "$r"
done
check "merged deny length = exxo ($exxo_deny) + $extra new rules" \
    test "$(jq '.permissions.deny | length' "$(S exxo-openrouter)")" -eq $((exxo_deny + extra))
check "shared-floor pulumi env open rules appear exactly once" \
    test "$(jq '[.permissions.deny[] | select(. == "Bash(pulumi env open*)" or . == "Bash(* pulumi env open*)")] | length' "$(S exxo-openrouter)")" -eq 2

# OAuth-only shared MCP servers are denied for workers; shared denials survive.
for n in datadog boards; do
    check "deniedMcpServers includes $n" \
        jqeq exxo-openrouter ".deniedMcpServers | any(.serverName == \"$n\")" true
done
check "shared deniedMcpServers kept" \
    jqeq exxo-openrouter '.deniedMcpServers | any(.serverName == "plugin:data:hex")' true

# Allow set: exactly the inherited one; nothing from the overlay.
check "allow set equals exxo's" \
    test "$(jq -c '.permissions.allow' "$(S exxo-openrouter)")" = "$(jq -c '.permissions.allow' "$(S exxo)")"
for r in 'Bash(git push *)' 'Bash(gh pr merge*)'; do
    check "not allowed: $r" bash -c "! jq -e --arg r '$r' '.permissions.allow | index([\$r]) != null' '$(S exxo-openrouter)' >/dev/null"
done
check "inherited gh pr view grant kept" has exxo-openrouter allow 'Bash(gh pr view:*)'
check "inherited gh pr list grant kept" has exxo-openrouter allow 'Bash(gh pr list:*)'

# No deny pattern may block legitimate worker commands.
while IFS= read -r pat; do
    case "$pat" in Bash\(*\)) p="${pat#Bash(}"; p="${p%)}" ;; *) continue ;; esac
    for cmd in 'git push origin job/smoke-1' 'gh pr view 1' 'gh pr list'; do
        # shellcheck disable=SC2053
        if [[ "$cmd" == $p ]]; then bad "deny $pat blocks: $cmd"; fi
    done
done < <(jq -r '.permissions.deny[]' "$(S exxo-openrouter)")
ok "no deny pattern matches job-branch push / gh pr view / gh pr list"

# Every key-reading spelling is caught by at least one deny pattern.
# shellcheck disable=SC2016  # literal text, not expanded
for cmd in 'cat ~/keys/openrouter.key' 'cat -n $HOME/keys/x' 'echo a | grep k /Users/tim/keys/x' 'cp ~/keys/x /tmp'; do
    hit=0
    while IFS= read -r pat; do
        case "$pat" in Bash\(*\)) p="${pat#Bash(}"; p="${p%)}" ;; *) continue ;; esac
        # shellcheck disable=SC2053
        if [[ "$cmd" == $p ]]; then hit=1; break; fi
    done < <(jq -r '.permissions.deny[]' "$(S exxo-openrouter)")
    check "deny pattern matches: $cmd" test "$hit" -eq 1
done

# Hooks: PreToolUse arrays concatenate across layers. exxo-openrouter keeps
# every shared PreToolUse entry (the squad hooks among them), then the exxo
# fragment's (none today: it carries no hooks), then the guard; the exxo
# contexts get shared + the exxo fragment's PreToolUse; personal's hooks equal
# the plain shared merge.
GUARD_CMD="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$C/settings.overlay.exxo-openrouter.json")"
check "guard hook command names the guard and ends with its marker" \
    bash -c 'case "$1" in *scripts/claude-openrouter-guard*"# claude-openrouter-guard") exit 0;; *) exit 1;; esac' _ "$GUARD_CMD"
# Fail closed: with python3 unreachable the hook must emit a deny decision,
# not exit 127 (a non-blocking error). Real guard via a fake $HOME/dev/dotfiles.
mkdir -p "$T/ghome/dev" "$T/nopath"
ln -s "$SRC_REPO" "$T/ghome/dev/dotfiles"
nop_out="$(HOME="$T/ghome" PATH="$T/nopath" /bin/sh -c "$GUARD_CMD" </dev/null 2>/dev/null)"; nop_rc=$?
check "guard hook, python3 missing: exits 0" test "$nop_rc" -eq 0
check "guard hook, python3 missing: emits deny" \
    bash -c 'jq -e ".hookSpecificOutput.permissionDecision == \"deny\"" <<<"$1" >/dev/null' _ "$nop_out"
ok_out="$(echo '{"session_id":"s","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' \
    | HOME="$T/ghome" SQUAD_GUARD_LOG="$T/guard.jsonl" /bin/sh -c "$GUARD_CMD" 2>/dev/null)"; ok_rc=$?
check "guard hook, python3 present: benign command passes silently" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ "$ok_rc" "$ok_out"
echo '{"session_id":"s","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh pr merge 1"}}' \
    | HOME="$T/ghome" SQUAD_GUARD_LOG="$T/guard.jsonl" /bin/sh -c "$GUARD_CMD" >"$T/deny.out" 2>/dev/null
check "guard hook, python3 present: merge still denied" grep -q '"deny"' "$T/deny.out"
check "exxo-openrouter PreToolUse = shared PreToolUse + guard" \
    test "$(jq -c '.hooks.PreToolUse' "$(S exxo-openrouter)")" = \
         "$(jq -c --arg c "$GUARD_CMD" '(.[0].hooks.PreToolUse + (.[1].hooks.PreToolUse // [])) + [{matcher:"Bash", hooks:[{type:"command", command:$c}]}]' -s "$C/settings.shared.json" "$C/settings.exxo.json")"
check "exxo-openrouter other hook events = exxo's" \
    test "$(jq -c '.hooks | del(.PreToolUse)' "$(S exxo-openrouter)")" = "$(jq -c '.hooks | del(.PreToolUse)' "$(S exxo)")"
for pair in personal:personal exxo:exxo exxo-personal:exxo; do
    ctx="${pair%%:*}"; acct="${pair##*:}"
    check "$ctx: hooks unchanged (shared * account)" \
        test "$(jq -c '.hooks' "$(S "$ctx")")" = "$(jq -cs '. as $f | ($f[0] * $f[1]) | .hooks.PreToolUse = (($f[0].hooks.PreToolUse // []) + ($f[1].hooks.PreToolUse // [])) | .hooks' "$C/settings.shared.json" "$C/settings.$acct.json")"
    check "$ctx: no guard hook" bash -c "! grep -q claude-openrouter-guard '$(S "$ctx")'"
done

# SETTINGS_MERGE concatenates hook arrays per event and leaves events only
# one side has untouched.
MERGE_EXPR="$(awk "/^SETTINGS_MERGE='/{f=1;next} f&&/^'/{exit} f" "$REPO/scripts/claude-sync")"
merged="$(jq -cs "$MERGE_EXPR" \
    <(echo '{"hooks":{"PreToolUse":[{"matcher":"A"}],"Stop":[{"matcher":"S"}]}}') \
    <(echo '{"hooks":{"PreToolUse":[{"matcher":"B"}],"SessionEnd":[{"matcher":"E"}]}}'))"
check "SETTINGS_MERGE: hook arrays concatenate" \
    test "$merged" = '{"hooks":{"PreToolUse":[{"matcher":"A"},{"matcher":"B"}],"Stop":[{"matcher":"S"}],"SessionEnd":[{"matcher":"E"}]}}'

# Other contexts are untouched by the overlay.
for ctx in personal exxo exxo-personal; do
    check "$ctx: no OpenRouter env" \
        jq -e '(.env // {}) | has("ANTHROPIC_BASE_URL") or has("CLAUDE_CODE_SUBAGENT_MODEL") | not' "$(S $ctx)" >/dev/null
    check "$ctx: no apiKeyHelper" jq -e '.apiKeyHelper == null' "$(S $ctx)" >/dev/null
    leaked=0
    for r in "${WORKER_DENY[@]}"; do
        case "$r" in 'Bash(pulumi env open*)'|'Bash(* pulumi env open*)') continue ;; esac
        has "$ctx" deny "$r" && leaked=$((leaked + 1))
    done
    check "$ctx: no worker deny rules" test "$leaked" -eq 0
done

# Sharing: only plugins is linked to exxo.
check "plugins symlinked to exxo's" test "$(readlink "$OR/plugins")" = "$FAKE/.claude-exxo/plugins"
for e in projects history.jsonl file-history plans tasks todos paste-cache; do
    check "$e is not shared" bash -c "[ ! -e '$OR/$e' ] && [ ! -L '$OR/$e' ]"
done
for d in skills agents; do
    check "$d is a real dir" bash -c "[ -d '$OR/$d' ] && [ ! -L '$OR/$d' ]"
    check "$d matches exxo's entries" \
        diff <(ls "$OR/$d") <(ls "$FAKE/.claude-exxo/$d")
done
check "CLAUDE.md identical to exxo's" cmp -s "$OR/CLAUDE.md" "$FAKE/.claude-exxo/CLAUDE.md"
# The shared note documents the exception, so every context carries it, and
# the openrouter context adds no headings of its own.
for ctx in personal exxo exxo-personal exxo-openrouter; do
    check "$ctx: CLAUDE.md mentions exxo-openrouter" grep -q 'exxo-openrouter' "$FAKE/.claude-$ctx/CLAUDE.md"
done
check "exxo-openrouter CLAUDE.md has as many ## headings as exxo's" \
    test "$(grep -c '^## ' "$OR/CLAUDE.md")" -eq "$(grep -c '^## ' "$FAKE/.claude-exxo/CLAUDE.md")"

# Idempotence and --diff.
sync >"$T/again.log" 2>&1; check "second run exits 0" test "$?" -eq 0
out="$(sync --diff 2>&1)"
check "diff: exxo-openrouter settings identical" \
    bash -c "awk '/exxo-openrouter vs repo/{f=1;next} f&&/^  identical/{print \"y\";exit} f&&/==>/{exit}' <<<\"\$1\" | grep -q y" _ "$out"

# A real (unshared) plugins dir is warned about and left alone.
HOME="$FAKE2" "$REPO/scripts/claude-sync" >"$T/real.log" 2>&1; check "real plugins dir: exits 0" test "$?" -eq 0
check "real plugins dir: warned" grep -q 'real (unshared) entry' "$T/real.log"
check "real plugins dir: left alone" bash -c "[ -d '$FAKE2/.claude-exxo-openrouter/plugins' ] && [ ! -L '$FAKE2/.claude-exxo-openrouter/plugins' ]"

[ "$fail" = 0 ] && echo "all claude-sync openrouter tests passed"
exit "$fail"
