# Shared POSIX-shell config for bash and zsh — the MINIMAL working set:
# environment variables and PATH. Not feature parity with the fish config;
# aliases, prompt and completions stay shell-specific (see .bashrc).
#
# fish does not read this file (different syntax) — it reads local.sh directly
# and builds its own PATH. local.sh is the one source of truth all three share.
#
# Sourced from .zshenv (the only file every zsh reads, interactive or not) and
# from .bashrc above its interactive guard, so variables are present in
# non-interactive contexts too: ssh one-liners, cron, scripts, Claude Code.
#
# Must stay syntax-compatible with BOTH shells: no arrays, no [[ ]] regex, no
# bashisms zsh lacks. Must stay quiet — any output here corrupts scp/sftp and
# pollutes captured ssh output.

# ~~~ SHARED VARIABLES (from local.sh) ~~~ #
# GOROOT, GOPATH, NODE_VERSION, NVM_DIR, PNPM_HOME, STRAY_ROOT, DOTFILES_ROOT
if [ -f "$HOME/.config/local.sh" ]; then
    . "$HOME/.config/local.sh"
fi

# ~~~ VARIABLES (mirroring common.fish) ~~~ #

export KUBE_CONFIG_PATH="$HOME/.kube/config"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
# enable IAP ssh tunnel to use numpy on system to increase performance
export CLOUDSDK_PYTHON_SITEPACKAGES=1
# for getting claude code to use LSP plugins properly
# (https://github.com/anthropics/claude-code/issues/15148)
export ENABLE_LSP_TOOL=1

# enable TTY for GPG signing prompt. Only meaningful with a terminal attached —
# unguarded this both spawns a subprocess on every non-interactive shell and
# sets the literal string "not a tty".
if [ -t 0 ]; then
    GPG_TTY="$(tty)"
    export GPG_TTY
fi

# OpenAI key -> chatgpt-cli, opencommit
if [ -f "$HOME/keys/openai.key" ]; then
    OPENAI_KEY="$(cat "$HOME/keys/openai.key")"
    export OPENAI_KEY
    export OPENAI_API_KEY="$OPENAI_KEY"
fi

# ~~~ PATH ~~~ #
# Built AFTER local.sh so $GOROOT/$GOPATH/$PNPM_HOME are available.

# Capture the pristine PATH once, so re-sourcing rebuilds rather than stacks
if [ -z "$PATH_BASE" ]; then
    export PATH_BASE="$PATH"
fi

# idempotent append
add_to_path() {
    for dir in "$@"; do
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) export PATH="$PATH:$dir" ;;
        esac
    done
}

# Drop later repeats of an entry, keeping the first (which is the one that
# wins lookups anyway). PATH is rebuilt from the live PATH — by .zprofile after
# path_helper, and by tools that append their own entries — so repeats
# accumulate without this. Read line-by-line rather than splitting on ":" in a
# for loop: zsh does not word-split unquoted parameters the way bash does, and
# several entries contain spaces.
dedupe_path() {
    _dp_new=""
    while IFS= read -r _dp_dir; do
        [ -n "$_dp_dir" ] || continue
        case ":$_dp_new:" in
            *":$_dp_dir:"*) continue ;;
        esac
        _dp_new="${_dp_new:+$_dp_new:}$_dp_dir"
    done <<EOF
$(printf '%s' "$PATH" | tr ':' '\n')
EOF
    PATH="$_dp_new"
    export PATH
    unset _dp_new _dp_dir
}

# homebrew forced in front so its bash/tools beat the system copies
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH_BASE"

add_to_path \
    "/usr/local/bin" \
    "$HOME/.local/bin" \
    "$HOME/.nix-profile/bin" \
    "$HOME/.local/share/fnm" \
    "$HOME/bin" \
    "$GOPATH/bin" \
    "$GOROOT/bin" \
    "$PNPM_HOME" \
    "$HOME/.orbstack/bin" \
    "$HOME/.yarn/bin" \
    "$HOME/.config/yarn/global/node_modules/.bin" \
    "/opt/homebrew/opt/mysql-client/bin" \
    "/Applications/Alacritty.app/Contents/MacOS" \
    "/Applications/Sublime Text.app/Contents/SharedSupport/bin" \
    "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"

# Cargo/Rust (a plain PATH export — cheap enough for every shell, unlike nvm,
# which stays in the interactive-only sections of .bashrc/.zshrc)
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Last, so it also catches whatever cargo's env (and anything sourced before
# this file) appended.
dedupe_path
