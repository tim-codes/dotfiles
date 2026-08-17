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
# zsh does not re-expand an alias inside its own expansion, so the inner
# claude is the PATH binary.
[ -d "$HOME/.claude-personal" ] && alias claude='CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude'
