echo "sourcing .bashrc"

# default bashrc for mac os
# Synced with ~/.config/fish/*.fish configuration

# ~/.bashrc: executed by bash(1) for non-login shells.

# ~~~ LOAD LOCAL CONFIG FIRST ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# Load local.sh BEFORE the interactive check so variables are available
# even in non-interactive shells (needed for Claude Code, scripts, etc.)
if [[ -f "$HOME/.config/local.sh" ]]; then
    source "$HOME/.config/local.sh"
fi


# ~~~ VARIABLES (from common.fish) ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

export KUBE_CONFIG_PATH="$HOME/.kube/config"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
# enable IAP ssh tunnel to use numpy on system to increase performance
export CLOUDSDK_PYTHON_SITEPACKAGES=1
# enable TTY for GPG signing prompt
export GPG_TTY=$(tty)
# for getting claude code to use LSP plugins properly
# (https://github.com/anthropics/claude-code/issues/15148)
export ENABLE_LSP_TOOL=1

# OpenAI key -> chatgpt-cli, opencommit
if [[ -f ~/keys/openai.key ]]; then
    export OPENAI_KEY=$(cat ~/keys/openai.key)
    export OPENAI_API_KEY=$OPENAI_KEY
fi

# ~~~ PATH (from common.fish and mac.fish) ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# NOTE: PATH setup happens AFTER local.sh is loaded so we can use
# $GOROOT, $GOPATH, $PNPM_HOME from local.sh

# Capture original PATH
if [[ -z "$PATH_BASE" ]]; then
    export PATH_BASE="$PATH"
fi

# Helper function to add to PATH idempotently
add_to_path() {
    for dir in "$@"; do
        if [[ ":$PATH:" != *":$dir:"* ]]; then
            export PATH="$PATH:$dir"
        fi
    done
}

# Reset PATH and rebuild it
# Note: forcing homebrew in front so we have homebrew bash in front of system bash
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH_BASE"

# Add all paths from fish config
# Now $GOROOT, $GOPATH, $PNPM_HOME are available from local.sh
add_to_path \
    "/usr/local/bin" \
    "$HOME/.local/bin" \
    "$HOME/.nix-profile/bin" \
    "$HOME/.local/share/fnm" \
    "$HOME/bin" \
    "$GOPATH/bin" \
    "$GOROOT/bin" \
    "$PNPM_HOME" \
    "$HOME/.yarn/bin" \
    "$HOME/.config/yarn/global/node_modules/.bin" \
    "/Applications/Alacritty.app/Contents/MacOS" \
    "/Applications/Sublime Text.app/Contents/SharedSupport/bin" \
    "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"

# Cargo/Rust
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
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

