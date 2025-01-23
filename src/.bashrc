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

if [[ -f "$HOME/.config/local.sh" ]]; then
    source "$HOME/.config/local.sh"
    source $HOME/.config/zsh/zsh_$DOTFILES_PLATFORM
else
  echo "Warning: $HOME/.config/local.sh not found. Shell not configured."
fi

# nvm configuration
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Calling nvm use automatically in a directory with a .nvmrc file
# see: https://github.com/nvm-sh/nvm?tab=readme-ov-file#bash
# todo:
# bash: nvm_find_up: command not found
# bash: nvm: command not found
# bash: [: =: unary operator expected
# bash: nvm: command not found
# cdnvm() {
#     command cd "$@" || return $?
#     nvm_path="$(nvm_find_up .nvmrc | command tr -d '\n')"

#     # If there are no .nvmrc file, use the default nvm version
#     if [[ ! $nvm_path = *[^[:space:]]* ]]; then

#         declare default_version
#         default_version="$(nvm version default)"

#         # If there is no default version, set it to `node`
#         # This will use the latest version on your machine
#         if [ $default_version = 'N/A' ]; then
#             nvm alias default node
#             default_version=$(nvm version default)
#         fi

#         # If the current version is not the default version, set it to use the default version
#         if [ "$(nvm current)" != "${default_version}" ]; then
#             nvm use default
#         fi
#     elif [[ -s "${nvm_path}/.nvmrc" && -r "${nvm_path}/.nvmrc" ]]; then
#         declare nvm_version
#         nvm_version=$(<"${nvm_path}"/.nvmrc)

#         declare locally_resolved_nvm_version
#         # `nvm ls` will check all locally-available versions
#         # If there are multiple matching versions, take the latest one
#         # Remove the `->` and `*` characters and spaces
#         # `locally_resolved_nvm_version` will be `N/A` if no local versions are found
#         locally_resolved_nvm_version=$(nvm ls --no-colors "${nvm_version}" | command tail -1 | command tr -d '\->*' | command tr -d '[:space:]')

#         # If it is not already installed, install it
#         # `nvm install` will implicitly use the newly-installed version
#         if [ "${locally_resolved_nvm_version}" = 'N/A' ]; then
#             nvm install "${nvm_version}";
#         elif [ "$(nvm current)" != "${locally_resolved_nvm_version}" ]; then
#             nvm use "${nvm_version}";
#         fi
#     fi
# }
# alias cd='cdnvm'
# cdnvm "$PWD" || exit