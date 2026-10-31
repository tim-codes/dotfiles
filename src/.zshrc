# ~/.zshenv loads first and pulls in ~/.config/shell/common.sh (variables +
# PATH, shared with bash). This file is interactive-only extras.
#
# The pnpm block that used to live here — exporting PNPM_HOME and prepending it
# to PATH — is gone: local.sh exports it and common.sh puts it on PATH, now for
# every zsh rather than only interactive ones. pnpm's installer had written it
# here directly, through the stow symlink.

# nvm is slow to source, so it stays out of .zshenv (which runs for every
# script and ssh one-liner) and loads only for interactive shells.
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Claude context wrappers, mirroring fish's __claude_ctx (common.fish). Bare
# `claude` uses the personal CLAUDE_CONFIG_DIR context, never the default
# ~/.claude: a safety rail, and an interactive zsh (the fallback shell) is
# exactly where the unaliased command would otherwise slip through. Gated on
# the context existing so machines without the per-account split are untouched.
#
# Functions rather than aliases, because they also redirect the start
# directory: launching from $HOME asks to trust the whole home directory, and
# launching from a context dir treats config state as a workspace. Both run
# from ~/claude, the default working directory, via a subshell so the caller's
# shell stays where it was. `command claude` is the PATH binary, no recursion.
if [ -d "$HOME/.claude-personal" ]; then
    # Context dirs: the start-dir jump applies when launched from $HOME or any
    # of these. The one list to extend when a context is added.
    _claude_ctx_dirs=("$HOME" "$HOME/.claude-personal" "$HOME/.claude-reserve" "$HOME/.claude-exxo" "$HOME/.claude-exxo-personal" "$HOME/.claude-exxo-openrouter")
    # $1 = context dir, or "" for the default ~/.claude; the rest pass through.
    _claude_ctx() {
        local dir="$1" here="$PWD" d
        shift
        # The exxo-openrouter overlay env is inherited by anything a K3 session
        # spawns; every other context must not see it, so it is unset for the
        # launched process only. The openrouter wrapper is left untouched.
        local -a scrub=()
        if [ "$dir" != "$HOME/.claude-exxo-openrouter" ]; then
            for d in ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL CLAUDE_CODE_SUBAGENT_MODEL; do
                scrub+=(-u "$d")
            done
        fi
        local -a cfg=(-u CLAUDE_CONFIG_DIR)
        [ -n "$dir" ] && cfg=(CLAUDE_CONFIG_DIR="$dir")
        for d in "${_claude_ctx_dirs[@]}"; do
            if [ "$here" = "$d" ]; then
                mkdir -p "$HOME/claude"
                ( cd "$HOME/claude" && command env "${scrub[@]}" "${cfg[@]}" claude "$@" )
                return
            fi
        done
        command env "${scrub[@]}" "${cfg[@]}" claude "$@"
    }
    claude() { _claude_ctx "$HOME/.claude-personal" "$@"; }
    claude-personal() { _claude_ctx "$HOME/.claude-personal" "$@"; }
    # reserve: the second personal Max subscription, fully separate durable
    # state (see claude-reserve in common.fish).
    claude-reserve() { _claude_ctx "$HOME/.claude-reserve" "$@"; }
    claude-exxo() { _claude_ctx "$HOME/.claude-exxo" "$@"; }
    # The exxo overlay on the personal subscription (see common.fish).
    claude-exxo-personal() { _claude_ctx "$HOME/.claude-exxo-personal" "$@"; }
    # exxo-openrouter context (Kimi K3 workers). The key comes from the
    # overlay's apiKeyHelper, so only the config dir and start directory are
    # set here. Anti-goal: sets no env that could route any other context.
    claude-exxo-openrouter() { _claude_ctx "$HOME/.claude-exxo-openrouter" "$@"; }
    # Escape hatch: the retired default ~/.claude context. Using it RECREATES
    # ~/.claude and ~/.claude.json from scratch (fresh login/onboarding).
    claude-default() { _claude_ctx "" "$@"; }
fi

# ~~~ ALIASES (fish/.bashrc parity, interactive only) ~~~ #
alias t="tmux"
alias mp="mkdir -p"
command -v lsd >/dev/null 2>&1 && alias ls="lsd"
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
# pnpm is Homebrew's (scripts/brew-update) and honours each repo's packageManager pin itself; no corepack alias (node >= 25 no longer bundles corepack)
alias p="pnpm"
alias pu="pulumi"
alias gcp="gcloud"
alias dt="devtunnel"
alias ff="fastfetch"
alias batyaml="bat -l yaml"
alias batjson="bat -l json"
alias batmd="bat -l markdown"

# Git aliases
alias g="git"
alias gs='git status -sb'
alias gf='git fetch'
alias gfs='gf && gs'
alias gcl='git clone'
alias gm='git merge'
alias gp='git pull'
alias gwl='git worktree list'
alias ga='git add'
alias gap='ga --patch'
alias gl='git log --decorate'
alias glo='gl --oneline'
alias gls='gl --stat'
alias glg='gl --graph --oneline'
alias gb='git branch'
alias gc='git commit -m'
alias gcn='git commit --no-verify -m'
alias gca='git commit -a -m'
alias gcan='git commit -a --no-verify -m'
alias gr='git reset'
alias grev='git revert'
alias greb='git rebase'
alias gundo='git reset HEAD^'
alias gunstage='git reset HEAD --'
alias gpu='git push'
alias gpun='git push --no-verify'
alias gpuf='git push --force-with-lease'
alias gpunf='git push --no-verify --force-with-lease'
alias gch='git checkout'
alias gsw='git switch'
alias gsw-='git switch -'
