# ~~~ VARIABLES ~~~ #
# ~~~~~~~~~~~~~~~~~ #

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
# fnm configuration
if type -q fnm
    fnm install 18 &>/dev/null
    fnm install 20 &>/dev/null
    fnm default 20
    # fnm env --use-on-cd | source
end
# nvm configuration
if type -q nvm
    # set -x nvm_default_version $NODE_VERSION
    # nvm use $nvm_default_version &>/dev/null # override as the var is not being ignored by nvm
    nvm alias default $NODE_VERSION &>/dev/null
end
# Calling nvm use automatically in a directory with a .nvmrc file
# requires bass plugin
if type -q bass
  function nvm
    bass source ~/.nvm/nvm.sh --no-use ';' nvm $argv
  end
  # ~/.config/fish/functions/nvm_find_nvmrc.fish
  function nvm_find_nvmrc
    bass source ~/.nvm/nvm.sh --no-use ';' nvm_find_nvmrc
  end
  # ~/.config/fish/functions/load_nvm.fish
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
      # echo "Reverting to default Node version"
      nvm use default &>/dev/null
    end
  end
  load_nvm > /dev/stderr
end


# ~~~~~~ PATH ~~~~~~ #
# ~~~~~~~~~~~~~~~~~~ #

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
#  todo: fix this
function read_path_config
  set -l paths_to_add
  for line in (cat $HOME/.path.config)
    set line (string trim -- "$line")
    if test -n "$line" -a (string match -q -v '^#' "$line")
      set paths_to_add $paths_to_add $line
    end
  end
  echo $paths_to_add
end

set -x PATH $PATH_BASE
# add_to_path $paths_to_add

# todo: remove this (copy from .path.config)
add_to_path \
  "/usr/local/bin" \
  "$HOME/.local/bin" \
  "$HOME/.nix-profile/bin" \
  "$HOME/.local/share/fnm" \
  "$HOME/bin" \
  "/opt/homebrew/bin" \
  "/opt/homebrew/sbin" \
  "$GOPATH/bin" \
  "$GOROOT/bin" \
  "$PNPM_HOME" \
  "$HOME/.yarn/bin" \
  "$HOME/.config/yarn/global/node_modules/.bin" \
  "/Applications/Alacritty.app/Contents/MacOS"

function print_path
  echo $PATH | tr ' ' '\n' | sort | bat
end
alias ppath="print_path"

# ~~~~ ALIASES ~~~~ #
# ~~~~~~~~~~~~~~~~~ #

alias t="tmux"
alias rf="source ~/.config/fish/config.fish"

function restow
    if test -z "$DOTFILES_ROOT"
        echo "\$DOTFILES_ROOT is not set"
        return
    end
    set _dir "$(pwd)"
    cd $DOTFILES_ROOT && stow --target $HOME src
    cd $_dir
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
