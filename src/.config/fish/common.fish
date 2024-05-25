# set OpenAI API Key to opencommit config
if test -f ~/keys/openai.key
    set -x OPENAI_KEY $(cat ~/keys/openai.key)
end
if type -q opencommit
    opencommit config set OCO_OPENAI_API_KEY=$OPENAI_KEY 1&>/dev/null
end

# poetry completions
if type -q poetry
    poetry completions fish >~/.config/fish/completions/peotry.fish
end

# Fish Theme
set fish_theme eden

source $HOME/.local/share/omf/pkg/omf/functions/omf.fish

# Make the blue color for directories more readable
set -x LSCOLORS Exfxcxdxbxegedabagacad

set -x PATH $PATH $HOME/.cargo/bin
set -x PATH $PATH /usr/local/go/bin
set -x PATH $PATH $HOME/bin
set -x PATH $PATH $HOME/bin/google-cloud-sdk/bin
set -x PATH $PATH $HOME/.local/bin
set -x PATH $PATH $HOME/.nix-profile/bin
set -x PATH $PATH $HOME/.local/share/fnm

function dot-stow
    if not set -q $DOTFILES_ROOT
        echo "\$DOTFILES_ROOT is not set"
        exit 1
    end
    cd $DOTFILES_ROOT && stow --target $HOME src
end

if type -q nvm
    set -x NVM_DIR "$HOME/.nvm"
    # nodejs configuration
    set -x nvm_default_version 18
    nvm use $nvm_default_version &>/dev/null # override as the var is not being ignored by nvm
end

if type -q fnm
    fnm install 18 &>/dev/null
    fnm default 18
    fnm env --use-on-cd | source
end

alias pnpm="corepack pnpm"

alias t="tmux"
alias rf="source ~/.config/fish/config.fish"

# use exa for dir commands
alias ls="exa"
alias ll="exa -l"
alias la="exa -la"
alias l="ll"

alias mp="mkdir -p"

alias python="python3"
alias py="python"
alias tf="terraform"
alias pm="podman"
alias p="pnpm"
alias gcp="gcloud"
alias oc="opencommit"
alias ocn="opencommit --no-verify"

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

# git config
git config --global core.editor vim
git config --global push.autoSetupRemote true
git config --global pull.rebase true
git config --global user.name "Tim O'Connell"
git config --global user.email "tim@exxo.sh"

# Terraform aliases
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
