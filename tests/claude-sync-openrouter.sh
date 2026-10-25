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
    check "$v is moonshotai/kimi-k3" jqeq exxo-openrouter ".env.$v" 'moonshotai/kimi-k3'
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
