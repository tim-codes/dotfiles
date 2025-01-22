# ~~~ VARIABLES ~~~ #
# ~~~~~~~~~~~~~~~~~ #

set -x GOROOT "$HOME/sdk/go/go$GO_VERSION"
set -x GOPATH "$HOME/go/go$GO_VERSION"
set -x NVM_DIR "$HOME/.nvm"
set -x PNPM_HOME "$HOME/Library/pnpm"
set -x KUBE_CONFIG_PATH "$HOME/.kube/config"
set -x GOOGLE_APPLICATION_CREDENTIALS "$HOME/.config/gcloud/application_default_credentials.json"
# enable IAP ssh tunnel to use numpy on system to increase performance
set -x CLOUDSDK_PYTHON_SITEPACKAGES 1
# enable TTY for GPG signing prompt
set -x GPG_TTY $(tty)

# OpenAI key -> chatgpt-cli, opencommit
if test -f ~/keys/openai.key
  set -x OPENAI_KEY $(cat ~/keys/openai.key)
  set -x OPENAI_API_KEY $OPENAI_KEY
  if type -q opencommit
    opencommit config set OCO_OPENAI_API_KEY=$OPENAI_KEY 1&>/dev/null
  end
end

# poetry completions
if type -q poetry
    poetry completions fish >~/.config/fish/completions/peotry.fish
end
# nvm configuration
if type -q nvm
    set -x nvm_default_version 20
    nvm use $nvm_default_version &>/dev/null # override as the var is not being ignored by nvm
end
# fnm configuration
if type -q fnm
    fnm install 18 &>/dev/null
    fnm install 20 &>/dev/null
    fnm default 20
    # fnm env --use-on-cd | source
end

# ~~~~~~ PATH ~~~~~~ #
# ~~~~~~~~~~~~~~~~~~ #

#~~ PATH_BASE on mac looks like:
# /System/Cryptexes/App/usr/bin
# /Users/toe649/Library/Application
# /bin
# /opt/homebrew/bin
# /sbin
# /usr/bin
# /usr/local/bin
# /usr/local/laps
# /usr/sbin
# /var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin
# /var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin
# /var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin
# Support/JetBrains/Toolbox/scripts

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

#~~ reset PATH and rebuild it
set -x PATH $PATH_BASE
add_to_path \
  "$HOME/.local/bin" \
  "$HOME/.nix-profile/bin" \
  "$HOME/.local/share/fnm" \
  "$HOME/bin" \
  "/opt/homebrew/bin" \
  "/opt/homebrew/sbin" \
  # todo: figure out whitespace handling
  # "/Applications/Sublime Text.app/Contents/SharedSupport/bin" \
  # "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts" \
  "$GOPATH/bin" \
  "$GOROOT/bin" \
  "$PNPM_HOME" \
  "$HOME/.yarn/bin" \
  "$HOME/.config/yarn/global/node_modules/.bin"

function print_path
  echo $PATH | tr ' ' '\n' | sort
end

# ~~~~ ALIASES ~~~~ #
# ~~~~~~~~~~~~~~~~~ #

alias t="tmux"
alias rf="source ~/.config/fish/config.fish"

function restow
    if test -z "$DOTFILES_ROOT"
        echo "\$DOTFILES_ROOT is not set"
        return
    end
    cd $DOTFILES_ROOT && stow --target $HOME src
    cd -
    rf
end

alias pnpm="corepack pnpm"

# use lsd for dir commands
alias ls="lsd"
alias ll="lsd -l"
alias la="lsd -la"
alias l="ll"

alias mp="mkdir -p"
alias python="python3"
alias py="python"
alias pip="pip3"
alias tf="tofu"
alias pm="podman"
alias p="pnpm"
alias gcp="gcloud"
alias oc="opencommit"
alias ocn="opencommit --no-verify"
alias dt="devtunnel"
alias chat="chatgpt"

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
    # git switch $argv[1]
end

# # git config
# git config --global core.editor vim
# git config --global push.autoSetupRemote true
# git config --global pull.rebase true
# git config --global user.name "Tim O'Connell"
# git config --global user.email "tim@exxo.sh"

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
alias byaml="bat -l yaml"
alias bjson="bat -l json"

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
