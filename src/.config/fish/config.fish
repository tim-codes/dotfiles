# root config
set local_root $HOME/.config/local.sh
if not test -e $local_root
  touch $local_root
end
source $local_root

# load PATH injections
if test -f $HOME/.cargo/env.fish
  source $HOME/.cargo/env.fish
end

# load platform-specific fish config (inc. common config)
set -x fish_conf "$HOME/.config/fish/config.fish"
source $HOME/.config/fish/$DOTFILES_PLATFORM.fish

# ~~~ FISH SHELL ~~~ #
# ~~~~~~~~~~~~~~~~~~ #

# Fish Theme
set fish_theme eden

# Make the blue color for directories more readable
set -x LSCOLORS Exfxcxdxbxegedabagacad

# delete fish greeting in new shell
set -U fish_greeting ""

# set shell title to pwd
function fish_title
    set -q argv[1]; or set argv fish
    # Looks like ~/d/fish: git log
    # or /e/apt: fish
    echo (fish_prompt_pwd_dir_length=1 prompt_pwd): $argv;
end

# ~~~ LOCAL OVERRIDES ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~ #

# local aliases etc not commited to git
set local_fish $HOME/.config/fish/local.fish
if not test -e $local_fish
  touch $local_fish
end
source $local_fish