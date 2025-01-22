source ~/.config/fish/common.fish

set -x PNPM_HOME $HOME/.local/share/pnpm
set -x PATH $PNPM_HOME $PATH

alias bat="batcat"
alias python="python3"
