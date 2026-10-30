# Attach to the tmux session that belongs to this terminal: `scratch` in
# ghostty (its dropdown's session), `main` everywhere else (alacritty). Both
# exist from login (dev.tim.tmux-server LaunchAgent + restore-once.sh), so
# this attaches rather than creating. Inside tmux $TERM is tmux's own, so ask
# tmux for the outer terminal and switch the client instead of nesting.
# `tx <session>` targets that session instead (e.g. `tx h2gc`); tab completes
# the running sessions.
# Right after login the server or the restore can still be catching up, so
# outside tmux poll up to 5s for the session before letting attach fail.
function tx -d "Attach to a tmux session (default: ghostty scratch, else main)"
    set -l target $argv[1]
    if test -z "$target"
        set -l term $TERM
        if set -q TMUX
            set term (tmux display-message -p '#{client_termname}')
        end
        set target main
        string match -q '*ghostty*' -- $term; and set target scratch
    end
    if set -q TMUX
        tmux switch-client -t $target
    else
        if not tmux has-session -t $target 2>/dev/null
            echo "tx: waiting for tmux session '$target'..." >&2
            for i in (seq 20)
                sleep 0.25
                tmux has-session -t $target 2>/dev/null; and break
            end
        end
        tmux attach -t $target
    end
end
