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
