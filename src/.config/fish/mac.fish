source ~/.config/fish/common.fish

if test -d /opt/homebrew/Caskroom/google-cloud-sdk
  source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.fish.inc
end

# fish aliases to mimic bash `which`
alias which="type -p"
alias where="type -a"
