source ~/.config/fish/common.fish

set -x PNPM_HOME $HOME/.local/share/pnpm
set -x PATH $PATH $PNPM_HOME

# perl (e.g. git) doesnt like en_GB
set -x LANG en_US.UTF-8

alias bat="batcat"
alias python="python3"
