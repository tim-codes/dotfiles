source $HOME/.config/vars.fish

set -x fish_conf "$HOME/.config/fish/config.fish"
source $HOME/.config/fish/$DOTFILES_PLATFORM.fish

# local aliases etc not commited to git
set local_fish $HOME/.config/fish/local.fish
if not test -e $local_fish
    touch $local_fish
end
source $local_fish