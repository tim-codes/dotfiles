if [[ -f "$HOME/.config/local.sh" ]]; then
  source "$HOME/.config/local.sh"
  source $HOME/.config/zsh/zsh_$DOTFILES_PLATFORM
else
  echo "Warning: $HOME/.config/local.sh not found. Shell not configured."
fi
