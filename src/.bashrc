# default bashrc for mac os
# Synced with ~/.config/fish/*.fish configuration

# ~/.bashrc: executed by bash(1) for non-login shells.

# ~~~ SHARED CONFIG FIRST ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# Variables and PATH live in one file shared with zsh (which sources it from
# .zshenv), so the two non-fish shells cannot drift apart. It loads local.sh
# itself, and runs BEFORE the interactive check below so the variables exist in
# non-interactive shells too — Claude Code, scripts, ssh one-liners.
if [[ -f "$HOME/.config/shell/common.sh" ]]; then
    source "$HOME/.config/shell/common.sh"
fi

# nvm configuration
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# ~~~ LOCAL OVERRIDES ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~ #
# Note: local.sh is already loaded at the top of this file

# Alias definitions
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Add user-specific configurations
if [ -f ~/.bashrc_custom ]; then
    . ~/.bashrc_custom
fi

# ~~~ BREAK FOR NON-INTERACTIVE HERE ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# If not running interactively, don't do anything after this point
case $- in
    *i*) ;;
      *) return;;
esac

# Interactive-only from here on. Any output above the guard corrupts
# scp/sftp and pollutes captured ssh output, so the echo lives here.
echo "sourcing .bashrc"

# Set CLICOLOR if you want Ansi Colors in iTerm2
export CLICOLOR=1
export LSCOLORS="Exfxcxdxbxegedabagacad"

# Set up the prompt
export PS1="\u@\h \W$ "

# ~~~ ALIASES ~~~ #
# ~~~~~~~~~~~~~~~ #

alias t="tmux"
alias mp="mkdir -p"
if command -v lsd >/dev/null 2>&1; then
    alias ls="lsd"
fi
alias ll="ls -l"
alias la="ls -la"
alias l="ll"

alias j="just"
alias k="kubectl"
alias python="python3"
alias py="python"
alias pip="pip3"
alias tf="tofu"
alias pm="podman"
alias p="pnpm"
alias pnpm="corepack pnpm"
alias pu="pulumi"
alias gcp="gcloud"

# Git aliases
alias g="git"
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit -m'
alias gp='git pull'
alias gpu='git push'
alias gch='git checkout'
alias gsw='git switch'
alias gb='git branch'

# ~~~ BASH COMPLETION ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~ #

# Enable bash completion if available
if [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
elif [ -f /opt/homebrew/etc/bash_completion ]; then
    . /opt/homebrew/etc/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

