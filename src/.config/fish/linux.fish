source ~/.config/fish/common.fish

set -x PNPM_HOME $HOME/.local/share/pnpm
set -x PATH $PATH $PNPM_HOME

# perl (e.g. git) & nvim doesnt like en_GB

alias bat="batcat"
alias python="python3"
