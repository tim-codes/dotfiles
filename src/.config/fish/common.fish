# ~~~~~~ PATH ~~~~~~ #
# ~~~~~~~~~~~~~~~~~~ #
# PATH must be set first — everything below may need system binaries

#~~ capture original PATH
if test -z "$PATH_BASE"
  set -x PATH_BASE $PATH
end

#~~ append to $PATH idempotently...
function add_to_path
  for dir in $argv
    if not contains -- "$dir" $PATH
      set -x PATH $PATH "$dir"
    end
  end
end

# note: forcing homebrew in front so we have homebrew bash in front of system bash
# always include system paths to ensure basic commands (cat, curl, tty) are available
set -x PATH "/opt/homebrew/bin" "/opt/homebrew/sbin" $PATH_BASE
add_to_path \
  "/usr/local/bin" \
  "/usr/bin" \
  "/bin" \
  "/usr/sbin" \
  "/sbin" \
  "$HOME/.local/bin" \
  "$HOME/.nix-profile/bin" \
  "$HOME/bin" \
  "$GOPATH/bin" \
  "$GOROOT/bin" \
  "$PNPM_HOME" \
  "$HOME/.yarn/bin" \
  "$HOME/.config/yarn/global/node_modules/.bin" \
  "/opt/homebrew/opt/mysql-client/bin"

function print_path
  echo $PATH | tr ' ' '\n' | sort | bat
end
alias ppath="print_path"

# ~~~ VARIABLES ~~~ #
# ~~~~~~~~~~~~~~~~~ #

set -x KUBE_CONFIG_PATH "$HOME/.kube/config"
set -x GOOGLE_APPLICATION_CREDENTIALS "$HOME/.config/gcloud/application_default_credentials.json"
# enable IAP ssh tunnel to use numpy on system to increase performance
set -x CLOUDSDK_PYTHON_SITEPACKAGES 1
# enable TTY for GPG signing prompt
set -x GPG_TTY $(tty)
# for getting claude code to use LSP plugins properly
# (https://github.com/anthropics/claude-code/issues/15148)
set -gx ENABLE_LSP_TOOL 1

# ~~~ TOOL SETUP ~~~ #
# ~~~~~~~~~~~~~~~~~~ #

# OpenAI key -> chatgpt-cli, opencommit
if test -f ~/keys/openai.key
  set -x OPENAI_KEY $(cat ~/keys/openai.key)
  set -x OPENAI_API_KEY $OPENAI_KEY
  if type -q opencommit
    opencommit config set OCO_OPENAI_API_KEY=$OPENAI_KEY 1&>/dev/null
  end
end

# poetry completions — generated once, not on every shell start.
# `type -q poetry` only proves the pipx wrapper script exists; it does not run
# it. When a brew python upgrade removes the interpreter the venv pinned, the
# wrapper stays on PATH and every new shell printed its exec error before the
# prompt. Fix the cause with `pipx reinstall-all`; this keeps a broken poetry
# from leaking into shell startup, and drops poetry's ~300ms off every launch.
if type -q poetry; and not test -s ~/.config/fish/completions/poetry.fish
    poetry completions fish >~/.config/fish/completions/poetry.fish 2>/dev/null
    or rm -f ~/.config/fish/completions/poetry.fish
end
# node version manager (bash nvm via bass)
if type -q bass; and test -s "$NVM_DIR/nvm.sh"
  function nvm
    bass source $NVM_DIR/nvm.sh --no-use ';' nvm $argv
  end
  function nvm_find_nvmrc
    bass source $NVM_DIR/nvm.sh --no-use ';' nvm_find_nvmrc
  end

  # set default version from $NODE_VERSION (defined in local.sh)
  nvm alias default $NODE_VERSION &>/dev/null

  # auto-switch node version on cd when .nvmrc exists
  function load_nvm --on-variable="PWD"
    set -l default_node_version (nvm version default)
    set -l node_version (nvm version)
    set -l nvmrc_path (nvm_find_nvmrc)
    if test -n "$nvmrc_path"
      set -l nvmrc_node_version (nvm version (cat $nvmrc_path))
      if test "$nvmrc_node_version" = "N/A"
        nvm install (cat $nvmrc_path)
      else if test "$nvmrc_node_version" != "$node_version"
        nvm use $nvmrc_node_version
      end
    else if test "$node_version" != "$default_node_version"
      nvm use default &>/dev/null
    end
  end
  load_nvm >/dev/stderr
end

# zoxide
if type -q zoxide
    zoxide init fish | source
end

# ~~~~ ALIASES ~~~~ #
# ~~~~~~~~~~~~~~~~~ #

alias t="tmux"
alias rf="source ~/.config/fish/config.fish"
alias cl="cd ~/Claude && claude"

function restow
    if test -z "$DOTFILES_ROOT"
        echo "\$DOTFILES_ROOT is not set"
        return
    end
    set _dir "$(pwd)"
    cd $DOTFILES_ROOT && stow --target $HOME src
    cd $_dir

    # rebuild bat cache for theme updates
    if command -q bat
        if bat cache --build >/dev/null 2>&1
            echo "Rebuilt bat cache successfully"
        else
            echo "Failed to rebuild bat cache"
        end
    end

    rf
end

alias pnpm="corepack pnpm"

alias mp="mkdir -p"
if type -q lsd
  alias ls="lsd"
end
alias ll="ls -l"
alias la="ls -la"
alias l="ll"

alias j="just"
alias k="kubectl"
alias python="python3"
alias py="python"
alias pip="pip3"
alias tf="tofu"
alias pm="podman"
alias p="pnpm"
alias pu="pulumi"
alias gcp="gcloud"
alias aws-setup="aws configure sso"
alias aws-login="aws sso login"
alias aws-profile="aws --profile"

function aws-use
    if test -z "$argv[1]"
        echo "Current: $AWS_PROFILE"
        echo "Available profiles:"
        grep '^\[profile' ~/.aws/config | sed 's/\[profile /  /g' | sed 's/\]//g'
        return
    end
    set -gx AWS_PROFILE $argv[1]
    echo "Switched to AWS profile: $AWS_PROFILE"
end

function aws-clear
    set -e AWS_PROFILE
    echo "Cleared AWS_PROFILE"
end
alias oc="opencommit"
alias ocn="opencommit --no-verify"
alias dt="devtunnel"
alias chati="chatgpt --interactive"
function chat
    chatgpt $argv | bat --language=markdown
end

# Git aliases
alias g="git"
alias gs='git status -sb'
alias gcl='git clone'
alias gf='git fetch'
alias gm='git merge'
alias gp='git pull'

alias ga='git add'
alias gap='ga --patch'

alias gl='git log --decorate'
alias glo='gl --oneline'
alias gls='gl --stat'
alias glg='gl --graph --oneline'
function glr
    git log $argv origin/(git rev-parse --abbrev-ref HEAD)
end
alias glrg='glr --graph --oneline'
alias glrs='glr --stat'

function gd
    git diff --color $argv[1] | diff-so-fancy | bat
end
alias gds="git diff --staged --color | diff-so-fancy | bat"

alias gb='git branch'
alias gbl='gb -l | cat'
alias gblr='gb -lr | cat'

alias gc='git commit -m'
alias gcn='git commit --no-verify -m'
alias gca='git commit -a -m'
alias gcan='git commit -a --no-verify -m'

alias gr='git reset'
alias grev='git revert'
alias greb='git rebase'
alias grebi='greb --interactive'
alias gundo='gr HEAD^'
alias gunstage='gr HEAD --'

alias gpu='git push'
alias gpun='gpu --no-verify'
alias gpuf='gpu --force-with-lease'
alias gpunf='gpu --no-verify --force-with-lease'
alias gpufn='gpunf'
alias godel='gpu --no-verify --delete origin'

alias gch='git checkout'
function gchh
    set resetting (echo $argv | grep -E 'package.json|pnpm-lock.yaml')
    if $resetting
        echo "manifests changed, running install hook"
        git checkout HEAD -- $argv
    else
        echo "manifests unchanged, skipping install hook"
        git -c core.hooksPath=/dev/null checkout HEAD -- $argv
    end
end
alias gsw='git switch'
alias gsw-='git switch -'
function gswp
    git pull origin $argv[1]:$argv[1]
    # todo: why is this line disabled?
    # git switch $argv[1]
end

# Tofu aliases
alias tfi="tf init"
alias tfpx="tf plan" # base plan
alias tfp="tfpx -lock=false" # plan (no-lock)
alias tfpr="tfpx -lock=false -refresh-only" # refresh
alias tfpl="tfpx -lock=true" # plan (lock)
alias tfpc="tfpx -lock=true -input=false -out=plan.cache" # plan to file
alias tfa="tf apply" # apply
alias tfac="tfa -input=false plan.cache" # apply from file

# bat aliases
alias batyaml="bat -l yaml"
alias batjson="bat -l json"
alias batmd="bat -l markdown"

function ip-local
    ifconfig | grep broadcast | awk '{print $2}'
end

function ip-public
    curl -s ipinfo.io | jq '.ip' -r
end

function ip-public-detailed
    curl -s ipinfo.io | jq
end

# Clear docker container logs <container>
function docker-clear
    echo "" >$(docker inspect --format='{{.LogPath}}' $1)
end

# Remove all stopped containers
function docker-prune-stopped
    docker rm $(docker ps -a -q)
end

# ~~~~ HELP TUI ~~~~ #
# ~~~~~~~~~~~~~~~~~~ #

# Parse custom functions/aliases from this file at load time
set -g _help_entries
set -l _common_file (status filename)
set -l _prev_comment ""
set -l _lines (cat $_common_file)
for _line in $_lines
    # Track comment lines (only single-line comments above functions)
    if string match -rq '^\s*#\s+(?!~)(.+)' -- $_line
        set _prev_comment (string match -rg '^\s*#\s+(.+)' -- $_line)
    else
        # One-liner alias: show expansion
        if string match -rq '^\s*alias\s+' -- $_line
            set -l _parts (string match -rg '^\s*alias\s+(\S+?)=[\"\'](.+?)[\"\']' -- $_line)
            if test (count $_parts) -ge 2
                set -a _help_entries (printf '%s\t%s' $_parts[1] "$_parts[2]")
            end
        # Multi-line function: show comment if present
        else if string match -rq '^\s*function\s+' -- $_line
            set -l _fname (string match -rg '^\s*function\s+(\S+)' -- $_line)
            if test -n "$_fname"; and not contains $_fname help add_to_path print_path nvm nvm_find_nvmrc load_nvm fish_title
                if test -n "$_prev_comment"
                    set -a _help_entries (printf '%s\t%s' $_fname "$_prev_comment")
                else
                    set -a _help_entries "$_fname"
                end
            end
        end
        set _prev_comment ""
    end
end

alias h="help"
function help
    set -l selected (printf '%s\n' $_help_entries | sort | column -t -s \t | fzf --prompt="Commands > " --height=100% --layout=reverse)
    or return
    set -l cmd (string match -rg '^(\S+)' -- $selected)
    commandline -i $cmd
end

# Claude Code CLI per account. Lives in common.fish, not mac.fish: the context
# split applies to Linux workstations and remotes too — only the Claude DESKTOP
# launchers are macOS-only (see mac.fish).
#
# Separate CLAUDE_CONFIG_DIR = separate login and session state — verified
# isolated: a run under CLAUDE_CONFIG_DIR writes that context's own
# .claude.json and leaves the home-level one untouched.
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
# All arguments after the context dir pass straight through, so
# `claude-exxo --model fable --effort medium -p ...` works as if calling claude
# directly. Those flags are session-scoped and never touch settings.json; the
# in-session `/model` and `/effort` DO write your default, which is a habit to
# avoid rather than something to guard against — a rewrite shows up in
# `git diff` on files/claude/settings.json and is reverted there.
#
# Starting in $HOME makes Claude ask to trust the ENTIRE home directory — a
# huge scope granted in one keystroke — and starting in ANOTHER account's
# context dir is a leftover from a previous session, not a place to work. Both
# are redirected into this context's own dir: small, already Claude's own, and
# a sane thing to trust. Any real working directory is left alone. The cd is
# not undone afterwards: you asked for this context, so ending up in it is the
# expected result.
function __claude_ctx --description 'Run claude in a per-account config context'
    set -l dir $argv[1]
    set -e argv[1]
    set -l home (path resolve $HOME)
    set -l here (path resolve .)
    set -l target (path resolve $dir)
    set -l ctx_dirs $home/.claude $home/.claude-personal $home/.claude-exxo
    if test "$here" = "$home"; or contains -- "$here" $ctx_dirs
        test "$here" = "$target"; or cd $target
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

