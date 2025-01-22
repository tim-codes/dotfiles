# default bashrc for mac os
# todo: handle linux distros also

# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Set PATH, include user's private bin if it exists
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/bin"

# Set CLICOLOR if you want Ansi Colors in iTerm2
export CLICOLOR=1

# Set up the prompt
export PS1="\u@\h \W$ "

# Alias definitions.
# You may want to put all your additions into a separate file like ~/.bash_aliases,
# so you can maintain them easily.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Enable bash completion if available
if [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
elif [ -f /opt/homebrew/etc/bash_completion ]; then
    . /opt/homebrew/etc/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Add user-specific configurations
if [ -f ~/.bashrc_custom ]; then
    . ~/.bashrc_custom
fi

# ~~~ OVERLAY ~~~ #
# ~~~~~~~~~~~~~~~ #

# todo: handle linux distros also
source $HOME/.config/local/zsh/zsh_mac