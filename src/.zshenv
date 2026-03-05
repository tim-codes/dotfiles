# echo "sourcing ~/.zshenv"

# .zshenv - Loaded for ALL zsh shells (interactive and non-interactive)
# This is the ONLY file sourced by non-interactive zsh shells
# Critical for Claude Code, scripts, and other non-interactive contexts

# Load shared configuration (variables like $GOROOT, $GOPATH, $PNPM_HOME)
# if [[ -f "$HOME/.config/local.sh" ]]; then
#   source "$HOME/.config/local.sh"
# fi

# Set PATH with all required directories
# echo "GOROOT=${GOROOT}"
# export GOROOT="/Users/tim/sdk/go/go1.25.3"
# export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.nix-profile/bin:$HOME/.local/share/fnm:$HOME/bin:$GOPATH/bin:$GOROOT/bin:$PNPM_HOME:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:/Applications/Alacritty.app/Contents/MacOS:/Applications/Sublime Text.app/Contents/SharedSupport/bin:$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"
# export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.nix-profile/bin:$HOME/bin:$GOPATH/bin:$GOROOT/bin:$PNPM_HOME"
#
# # Cargo/Rust
# if [[ -f "$HOME/.cargo/env" ]]; then
#   source "$HOME/.cargo/env"
# fi
#
# # Additional environment variables from fish common.fish
# export KUBE_CONFIG_PATH="$HOME/.kube/config"
# export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
# export CLOUDSDK_PYTHON_SITEPACKAGES=1
# export GPG_TTY=$(tty)
#
# # OpenAI key
# if [[ -f ~/keys/openai.key ]]; then
#   export OPENAI_KEY=$(cat ~/keys/openai.key)
#   export OPENAI_API_KEY=$OPENAI_KEY
# fi
