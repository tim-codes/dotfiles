source ~/.config/fish/common.fish

# gcloud: sets CLOUDSDK_ROOT_DIR and puts the SDK's own bin on PATH.
# Anchored on brew's share/ symlink rather than the Caskroom: the cask was
# renamed google-cloud-sdk -> gcloud-cli, and the old path silently stopped
# matching, so this never loaded. share/ survives the rename, and checking both
# prefixes covers Apple Silicon and Intel.
for gcloud_sdk in /opt/homebrew/share/google-cloud-sdk /usr/local/share/google-cloud-sdk
  if test -f $gcloud_sdk/path.fish.inc
    source $gcloud_sdk/path.fish.inc
    break
  end
end

# AWS CLI completions
if type -q aws
  complete -c aws -f -a "(aws_completer)"
end

# fish aliases to mimic bash `which`
alias which="type -p"
alias where="type -a"

# Claude Code CLI per account (separate CLAUDE_CONFIG_DIR = separate login/session state).
# Bare `claude` is pinned to the personal context so the default ~/.claude
# context can't be used by accident (wrong-account guard). Safe despite the
# name collision: `alias` defines a fish *function* claude, but `env` is an
# external command whose exec does a plain PATH lookup, so the inner `claude`
# resolves to ~/.local/bin/claude, never back into the function.
# Contexts are created by scripts/claude-contexts.
alias claude='env CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude'
alias claude-personal='env CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude'
alias claude-exxo='env CLAUDE_CONFIG_DIR="$HOME/.claude-exxo" claude'

# Claude Desktop per account (separate Electron user-data dirs; default "Claude" dir retired)
alias claude-d-personal='open -na "Claude" --args --user-data-dir="$HOME/Library/Application Support/Claude-Personal"'
alias claude-d-exxo='open -na "Claude" --args --user-data-dir="$HOME/Library/Application Support/Claude-Exxo"'

set -x PATH $PATH "/Applications/Alacritty.app/Contents/MacOS"
set -x PATH $PATH "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
set -x PATH $PATH "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"

# OrbStack docker CLI (its installer only wires ~/.zprofile, see there)
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Homelab integration functions (mbp-claude, ...) — that repo owns machines'
# roles and inter-host wiring, this repo owns $HOME, so homelab keeps the
# content and dotfiles owns the single line that loads it. See ADR-012 in
# ~/dev/homelab/docs/adr/. Absent on machines with no homelab clone.
for f in $HOME/dev/homelab/projects/*/files/fish/*.fish
  test -f $f; and source $f
end
