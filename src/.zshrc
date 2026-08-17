# ~/.zshenv loads first and pulls in ~/.config/shell/common.sh (variables +
# PATH, shared with bash). This file is interactive-only extras.
#
# The pnpm block that used to live here — exporting PNPM_HOME and prepending it
# to PATH — is gone: local.sh exports it and common.sh puts it on PATH, now for
# every zsh rather than only interactive ones. pnpm's installer had written it
# here directly, through the stow symlink.

# nvm is slow to source, so it stays out of .zshenv (which runs for every
# script and ssh one-liner) and loads only for interactive shells.
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Wrong-account guard, mirroring fish's mac.fish: bare `claude` uses the
# personal CLAUDE_CONFIG_DIR context, never the default ~/.claude. A safety
# rail, not fish parity — an interactive zsh (the fallback shell) is exactly
# where the unaliased command would otherwise slip through. Gated on the
# context existing so machines without the per-account split are untouched.
#
# A function rather than an alias, because it also redirects a bare $HOME start
# into the context dir — launching from $HOME makes Claude ask to trust the
# whole home directory. The redirect runs in a subshell so the caller's $PWD is
# unchanged. `command claude` is the PATH binary, so there is no recursion.
if [ -d "$HOME/.claude-personal" ]; then
    claude() {
        local dir="$HOME/.claude-personal" rc
        if [ "$PWD" = "$HOME" ]; then
            ( cd "$dir" && CLAUDE_CONFIG_DIR="$dir" command claude "$@" ); rc=$?
        else
            CLAUDE_CONFIG_DIR="$dir" command claude "$@"; rc=$?
        fi
        # model/effortLevel back to the repo baseline; a /model change lasts
        # for that session only. Arguments pass straight through, so
        # `claude --model fable --effort medium` still works.
        claude-reset-defaults "$dir"
        return $rc
    }
fi
