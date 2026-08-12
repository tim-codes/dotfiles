source ~/.config/fish/common.fish

if test -d /opt/homebrew/Caskroom/google-cloud-sdk
  source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.fish.inc
end

# AWS CLI completions
if type -q aws
  complete -c aws -f -a "(aws_completer)"
end

# fish aliases to mimic bash `which`
alias which="type -p"
alias where="type -a"

# Claude Code CLI per account (separate CLAUDE_CONFIG_DIR = separate login/session state)
alias claude-personal='env CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude'
alias claude-exxo='env CLAUDE_CONFIG_DIR="$HOME/.claude-exxo" claude'

# Claude Desktop per account (separate Electron user-data dirs; default "Claude" dir retired)
alias claude-d-personal='open -na "Claude" --args --user-data-dir="$HOME/Library/Application Support/Claude-Personal"'
alias claude-d-exxo='open -na "Claude" --args --user-data-dir="$HOME/Library/Application Support/Claude-Exxo"'

set -x PATH $PATH "/Applications/Alacritty.app/Contents/MacOS"
set -x PATH $PATH "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
set -x PATH $PATH "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"
