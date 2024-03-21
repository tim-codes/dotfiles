# dotfiles

set .config/vars.fish
```fish
set -x DOTFILES_ROOT "$HOME/dev/personal/dotfiles"
set -x DOTFILES_PLATFORM "linux"
```

setup symlinks:
```fish
cd $DOTFILES_ROOT && stow --target ~ src
source ~/.config/fish/config.fish
```

