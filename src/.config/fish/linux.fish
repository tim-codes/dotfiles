source ~/.config/fish/common.fish

set -x PNPM_HOME $HOME/.local/share/pnpm
set -x PATH $PATH $PNPM_HOME

alias bat="batcat"
alias python="python3"
