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

# Claude Code CLI per account (separate CLAUDE_CONFIG_DIR = separate login and
# session state — verified isolated: a run under CLAUDE_CONFIG_DIR writes that
# context's own .claude.json and leaves the home-level one untouched).
#
# Bare `claude` is pinned to the personal context so the default ~/.claude can't
# be used by accident (wrong-account guard). Safe despite the name collision:
# `env` is an external command whose exec does a plain PATH lookup, so the inner
# `claude` resolves to ~/.local/bin/claude and never re-enters this function.
# Contexts are created by scripts/claude-contexts.
#
# Starting from $HOME makes Claude ask to trust the ENTIRE home directory — a
# huge, mostly irrelevant trust scope granted in one keystroke. So a bare $HOME
# start is redirected into the context dir itself: small, already Claude's own,
# and a sane thing to trust. Every other directory is left alone — an explicit
# `cd` into a project is the whole point. pushd/popd so the caller's shell comes
# back to where it started.
function __claude_ctx --description 'Run claude in a per-account config context'
    set -l dir $argv[1]
    set -e argv[1]
    if test (path resolve .) = (path resolve $HOME)
        pushd $dir
        env CLAUDE_CONFIG_DIR=$dir claude $argv
        set -l rc $status
        popd
        return $rc
    end
    env CLAUDE_CONFIG_DIR=$dir claude $argv
end

function claude --wraps claude --description 'claude in the personal context'
    __claude_ctx "$HOME/.claude-personal" $argv
end
function claude-personal --wraps claude --description 'claude in the personal context'
    __claude_ctx "$HOME/.claude-personal" $argv
end
function claude-exxo --wraps claude --description 'claude in the exxo (work) context'
    __claude_ctx "$HOME/.claude-exxo" $argv
end

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
