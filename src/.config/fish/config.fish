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

# update completions
source ~/.config/fish/completions.fish

# ~~~ FISH SHELL ~~~ #
# ~~~~~~~~~~~~~~~~~~ #

# Fish Theme
set fish_theme eden

# Make the blue color for directories more readable
set -x LSCOLORS Exfxcxdxbxegedabagacad

# gcloud runs on the python@3.12 virtualenv built by scripts/gcloud-setup (the
# Homebrew default, 3.14, breaks it: ssl.PROTOCOL_TLSv1 removed). It also holds
# numpy and grpcio. gcloud launches python with -S (no site-packages) unless
# SITEPACKAGES=1 or VIRTUAL_ENV is set; here that only exposes the
# virtualenv's own packages (include-system-site-packages = false).
set -x CLOUDSDK_PYTHON "$HOME/.config/gcloud/virtenv/bin/python"
set -x CLOUDSDK_PYTHON_SITEPACKAGES 1

# delete fish greeting in new shell
set -U fish_greeting ""

# set shell title to pwd
function fish_title
  set -q argv[1]; or set argv fish
  # Looks like ~/d/fish: git log
  # or /e/apt: fish
  echo (fish_prompt_pwd_dir_length=1 prompt_pwd): $argv;
end

# configure the prompt
# function fish_prompt
#   # remove the hostname prefix
#   set -l prompt_hostname ''
# end

# ~~~ LOCAL OVERRIDES ~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~ #

# local aliases etc not commited to git
set local_fish $HOME/.config/fish/local.fish
if not test -e $local_fish
  touch $local_fish
end
source $local_fish
