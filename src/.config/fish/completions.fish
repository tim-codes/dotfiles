# Define the base URL for Fish shell completions
set -l FISH_COMPLETIONS_URL "https://raw.githubusercontent.com/fish-shell/fish-shell/master/share/completions"

# Ensure the completions directory exists
mkdir -p ~/.config/fish/completions

if ! test -f ~/.config/fish/fish_completions
  echo "fish_completions file not found."
  exit 0
end

# Read the fish_completions file line by line
while read -l completion_file
    set -l local_path "$HOME/.config/fish/completions/$completion_file"
    set -l remote_url "$FISH_COMPLETIONS_URL/$completion_file.fish"

    # Check if the file already exists locally
    if not test -f "$local_path"
        echo "Fetching $completion_file..."
        curl -s -o "$local_path" "$remote_url"
    end
end < ~/.config/fish/fish_completions
