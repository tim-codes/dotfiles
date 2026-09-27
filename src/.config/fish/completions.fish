# Ensure the completions directory exists
mkdir -p ~/.config/fish/completions

# wt: complete branch names (local and remote) and claude contexts.
complete -c wt -f -a '(git for-each-ref --format="%(refname:lstrip=2)" refs/heads refs/remotes/origin 2>/dev/null | string replace -r "^origin/" "" | path sort -u)'
complete -c wt -s c -l context -x -a 'personal exxo exxo-personal'
complete -c wt -s n -l no-claude -d "worktree only, don't start claude"
