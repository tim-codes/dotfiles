if [[ -f "$HOME/.config/local.sh" ]]; then
  source "$HOME/.config/local.sh"
  source $HOME/.config/zsh/zsh_$DOTFILES_PLATFORM
else
  echo "Warning: $HOME/.config/local.sh not found. Shell not configured."
fi

# need to use this method for some reason, instead of declaring the bin dir in .path.config
if [[ -f $HOME/.cargo/env ]]; then
  source $HOME/.cargo/env
fi