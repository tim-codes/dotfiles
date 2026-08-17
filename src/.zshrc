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
# A function rather than an alias, because it also redirects the start
# directory: launching from $HOME asks to trust the whole home directory, and
# launching from another account's context dir is a leftover from a previous
# session. Both land in this context's own dir instead. The cd is not undone —
# you asked for this context. `command claude` is the PATH binary, no recursion.
if [ -d "$HOME/.claude-personal" ]; then
    claude() {
        local dir="$HOME/.claude-personal"
        case "$PWD" in
            "$HOME"|"$HOME"/.claude|"$HOME"/.claude-personal|"$HOME"/.claude-exxo)
                [ "$PWD" = "$dir" ] || cd "$dir" ;;
        esac
        CLAUDE_CONFIG_DIR="$dir" command claude "$@"
    }
fi
