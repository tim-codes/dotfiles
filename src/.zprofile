# Runs after /etc/zprofile, which on macOS invokes path_helper — that REORDERS
# PATH, hoisting the system directories in front of whatever .zshenv set. So
# the shared config is re-sourced here for login shells to restore the intended
# order (homebrew ahead of /usr/bin).
#
# Non-login shells never see path_helper and are already correct from .zshenv.

# OrbStack's own init goes FIRST, so common.sh's dedupe below tidies up after
# it. It appends ~/.orbstack/bin unconditionally, and common.sh lists that
# directory too — the entry is ours now, and this line is kept only for the zsh
# completions it adds to fpath.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# PATH_BASE is cleared first so common.sh re-captures it from the PATH that
# path_helper just produced. That matters: path_helper does not only reorder,
# it also ADDS the /etc/paths.d entries, which the value captured back in
# .zshenv predates — rebuilding from the older snapshot would drop them.
if [ -f "$HOME/.config/shell/common.sh" ]; then
    unset PATH_BASE
    . "$HOME/.config/shell/common.sh"
fi
