source ~/.config/fish/common.fish

if test -d /opt/homebrew/Caskroom/google-cloud-sdk
  source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.fish.inc
end

# fish aliases to mimic bash `which`
alias which="type -p"
alias where="type -a"

set -x PATH $PATH "/Applications/Alacritty.app/Contents/MacOS"
set -x PATH $PATH "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
set -x PATH $PATH "$HOME/Library/Application Support/Jetbrains/Toolbox/scripts"
