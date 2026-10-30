# Terminal keymap cheatsheet in the pager - tmux bindings, alacritty, and the
# ghostty dropdown, as actually configured here rather than tmux's defaults.
# Rendered through md, so it picks mdcat for the tables like any other doc.
function th -d "Terminal and tmux keymap cheatsheet"
    set -l sheet $HOME/.config/tmux/cheatsheet.md
    # The sheet is written with tmux's real prefix, C-a, which is right on every
    # platform. On macOS alacritty and ghostty also send it on Cmd+. (see their
    # configs), so show that chord there - and only there, followed by the
    # mac-only note on where the rebind lives, for debugging it.
    if test (uname) = Darwin
        begin
            sed -e 's/`C-a C-a`/`⌘. ⌘.`/g' \
                -e 's/`C-a /`⌘. /g' \
                -e 's/^Prefix is `C-a` (not `C-b`)\./Prefix is `⌘.` (Cmd+period), which the terminals send as the tmux prefix `C-a` - so `C-a` works too./' \
                $sheet
            cat $HOME/.config/tmux/cheatsheet.mac.md
        end | md
    else
        md $sheet
    end
end
