#!/bin/bash
# Tests for the claude-exxo-openrouter wrapper (zsh and fish). Stubs `claude`
# on PATH and uses a fake $HOME; never touches the real contexts and never
# sources the real shell config. Key supply is the settings' apiKeyHelper, so
# the wrapper must set only CLAUDE_CONFIG_DIR and the start directory.
# Usage: bash tests/claude-openrouter-wrapper.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FH="$T/home"
mkdir -p "$FH/.claude-personal" "$T/bin" "$FH/proj"
cat > "$T/bin/claude" <<'STUB'
#!/bin/sh
echo "cfg=${CLAUDE_CONFIG_DIR-UNSET}"
echo "tok=${ANTHROPIC_AUTH_TOKEN-UNSET}"
echo "key=${ANTHROPIC_API_KEY-UNSET}"
echo "cwd=$(pwd -P)"
echo "args=$*"
STUB
chmod +x "$T/bin/claude"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
has() { case "$1" in *"$2"*) ok "$3";; *) bad "$3 (wanted '$2' in: $1)";; esac; }

HP="$(cd "$FH" && pwd -P)"
run_zsh() { # $1 = start dir
    env -i HOME="$FH" PATH="$T/bin:/usr/bin:/bin:/opt/homebrew/bin" \
        zsh -f -c "source '$SRC_REPO/src/.zshrc' >/dev/null 2>&1; cd '$1' && claude-exxo-openrouter --model x -p y"
}

if command -v zsh >/dev/null; then
    out="$(run_zsh "$FH/proj")"; rc=$?
    [ $rc -eq 0 ] && ok "zsh: exits 0" || bad "zsh: exit $rc"
    has "$out" "cfg=$FH/.claude-exxo-openrouter" "zsh: CLAUDE_CONFIG_DIR is the openrouter context"
    has "$out" "tok=UNSET" "zsh: no ANTHROPIC_AUTH_TOKEN"
    has "$out" "key=UNSET" "zsh: no ANTHROPIC_API_KEY"
    has "$out" "args=--model x -p y" "zsh: args pass through"
    has "$out" "cwd=$HP/proj" "zsh: real project dir left alone"
    for d in "$FH" "$FH/.claude-exxo-openrouter"; do
        mkdir -p "$d"
        out="$(run_zsh "$d")"
        has "$out" "cwd=$HP/claude" "zsh: from ${d#"$FH"}/ starts in ~/claude"
    done
    cnt="$(grep -c '\.claude-exxo-openrouter' "$SRC_REPO/src/.zshrc")"
    [ "$cnt" -ge 3 ] && ok "zsh: guard lists include the new dir" || bad "zsh: guard lists missing the new dir ($cnt)"
else
    echo "note: zsh absent, skipping zsh checks"
fi

FISHF="$SRC_REPO/src/.config/fish/common.fish"
if command -v fish >/dev/null; then
    fish -n "$FISHF" && ok "fish -n common.fish" || bad "fish -n common.fish"
    out="$(env HOME="$FH" fish -c "source '$FISHF' 2>/dev/null; functions -q claude-exxo-openrouter; and echo defined" 2>&1)"
    has "$out" "defined" "fish: claude-exxo-openrouter defined"
    out="$(env HOME="$FH" PATH="$T/bin:$PATH" fish -c "source '$FISHF' 2>/dev/null; set -gx PATH '$T/bin' \$PATH; cd '$FH'; claude-exxo-openrouter --model x -p y" 2>&1)"
    has "$out" "cfg=$FH/.claude-exxo-openrouter" "fish: CLAUDE_CONFIG_DIR is the openrouter context"
    has "$out" "tok=UNSET" "fish: no ANTHROPIC_AUTH_TOKEN"
    has "$out" "cwd=$HP/claude" "fish: from \$HOME starts in ~/claude"
    has "$out" "args=--model x -p y" "fish: args pass through"
else
    echo "note: fish absent, skipping fish checks"
fi
exit $fail
