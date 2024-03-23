source ~/.config/fish/common.fish

set -x PNPM_HOME $HOME/.local/share/pnpm
set -x PATH $PATH $PNPM_HOME

# perl (e.g. git) & nvim doesnt like en_GB
set -x LANGUAGE en_US.UTF-8
set -x LANG en_US.UTF-8
set -x LC_ALL en-US.UTF-8
set -x LC_CTYPE en-US.UTF-8

alias bat="batcat"
alias python="python3"
