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
# launching from a context dir treats config state as a workspace. Both run
# from ~/claude, the default working directory, via a subshell so the caller's
# shell stays where it was. `command claude` is the PATH binary, no recursion.
if [ -d "$HOME/.claude-personal" ]; then
    # The exxo-openrouter overlay env is inherited by anything a K3 session
    # spawns; claude and claude-default must not see it, so it is unset for the
    # launched process only. claude-exxo-openrouter is left untouched.
    _claude_scrub=(-u ANTHROPIC_BASE_URL -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL -u ANTHROPIC_DEFAULT_FABLE_MODEL -u CLAUDE_CODE_SUBAGENT_MODEL)
    claude() {
        local dir="$HOME/.claude-personal"
        case "$PWD" in
            "$HOME"|"$HOME"/.claude-personal|"$HOME"/.claude-reserve|"$HOME"/.claude-exxo|"$HOME"/.claude-exxo-personal|"$HOME"/.claude-exxo-openrouter)
                mkdir -p "$HOME/claude"
                ( cd "$HOME/claude" && command env "${_claude_scrub[@]}" CLAUDE_CONFIG_DIR="$dir" claude "$@" )
                return ;;
        esac
        command env "${_claude_scrub[@]}" CLAUDE_CONFIG_DIR="$dir" claude "$@"
    }
    # reserve context: the second personal Max subscription, fully separate
    # durable state (see claude-reserve in common.fish). Same scrub as claude.
    claude-reserve() {
        local dir="$HOME/.claude-reserve"
        case "$PWD" in
            "$HOME"|"$HOME"/.claude-personal|"$HOME"/.claude-reserve|"$HOME"/.claude-exxo|"$HOME"/.claude-exxo-personal|"$HOME"/.claude-exxo-openrouter)
                mkdir -p "$HOME/claude"
                ( cd "$HOME/claude" && command env "${_claude_scrub[@]}" CLAUDE_CONFIG_DIR="$dir" claude "$@" )
                return ;;
        esac
        command env "${_claude_scrub[@]}" CLAUDE_CONFIG_DIR="$dir" claude "$@"
    }
    # exxo-openrouter context (Kimi K3 workers). The key comes from the
    # overlay's apiKeyHelper, so only the config dir and start directory are
    # set here. Anti-goal: sets no env that could route any other context.
    claude-exxo-openrouter() {
        local dir="$HOME/.claude-exxo-openrouter"
        case "$PWD" in
            "$HOME"|"$HOME"/.claude-personal|"$HOME"/.claude-reserve|"$HOME"/.claude-exxo|"$HOME"/.claude-exxo-personal|"$HOME"/.claude-exxo-openrouter)
                mkdir -p "$HOME/claude"
                ( cd "$HOME/claude" && CLAUDE_CONFIG_DIR="$dir" command claude "$@" )
                return ;;
        esac
        CLAUDE_CONFIG_DIR="$dir" command claude "$@"
    }
    # Escape hatch: the retired default ~/.claude context. Using it RECREATES
    # ~/.claude and ~/.claude.json from scratch (fresh login/onboarding).
    claude-default() {
        case "$PWD" in
            "$HOME"|"$HOME"/.claude-personal|"$HOME"/.claude-reserve|"$HOME"/.claude-exxo|"$HOME"/.claude-exxo-personal|"$HOME"/.claude-exxo-openrouter)
                mkdir -p "$HOME/claude"
                ( cd "$HOME/claude" && command env "${_claude_scrub[@]}" -u CLAUDE_CONFIG_DIR claude "$@" )
                return ;;
        esac
        command env "${_claude_scrub[@]}" -u CLAUDE_CONFIG_DIR claude "$@"
    }
fi
