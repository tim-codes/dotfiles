# Runs after /etc/zprofile, which on macOS invokes path_helper — that REORDERS
# PATH, hoisting the system directories in front of whatever .zshenv set. So
# the shared config is re-sourced here for login shells to restore the intended
# order (homebrew ahead of /usr/bin). It rebuilds from the $PATH_BASE captured
# on first load rather than stacking entries, so this is idempotent.
#
# Non-login shells never see path_helper and are already correct from .zshenv.
#
# PATH_BASE is cleared first so common.sh re-captures it from the PATH that
# path_helper just produced. That matters: path_helper does not only reorder,
# it also ADDS the /etc/paths.d entries, which the value captured back in
# .zshenv predates — rebuilding from the older snapshot would drop them.
if [ -f "$HOME/.config/shell/common.sh" ]; then
    unset PATH_BASE
    . "$HOME/.config/shell/common.sh"
fi

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
