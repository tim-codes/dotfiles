# Switch the terminal colour theme for the terminal it is run from.
#
#   theme            pick interactively (althemer TUI in alacritty, fzf in ghostty)
#   theme NAME       set directly
#   theme -s/--sync  pick in althemer, then set every terminal and tmux session
#   theme -l         list available themes
#
# Without --sync only the invoking terminal changes, so the ghostty dropdown and
# the alacritty windows can wear different themes. tmux's global palette
# follows alacritty (the main terminal); ghostty's theme goes to the scratch
# session - the dropdown's - as session-scoped overrides in
# ~/.config/tmux/theme-scratch.conf, which --sync removes. The terminal is read from the tmux
# client when inside tmux (client_termname), else from the environment; an
# unrecognised one (e.g. a tm2 ssh attach) is refused rather than guessed.
#
# The alacritty themes under ~/.config/alacritty/themes are the single source
# of truth; ghostty's equivalents are generated from them by
# scripts/gen-ghostty-themes. Each terminal reads a small machine-local
# indirection file naming the active theme, so a switch is short writes rather
# than any colour parsing.
#
# Alacritty picks the change up by itself (live_config_reload). Ghostty has no
# auto-reload - that is an explicit upstream wontfix - so it is signalled with
# SIGUSR2, which it handles ("reloading configuration in response to SIGUSR2").
function theme -d "Switch the terminal theme (invoking terminal, or all with --sync)"
    argparse l/list s/sync -- $argv
    or return

    set -l themes_dir $HOME/.config/alacritty/themes
    set -l ghostty_conf $HOME/.config/ghostty/theme.conf

    if set -q _flag_list
        for _t in $themes_dir/*.toml
            basename $_t .toml
        end
        return 0
    end

    set -l targets alacritty ghostty
    if set -q _flag_sync
        set argv
    else
        set -l term
        if set -q TMUX
            set term (tmux display-message -p '#{client_termname}' 2>/dev/null)
        else if test "$TERM_PROGRAM" = ghostty
            set term xterm-ghostty
        else if set -q ALACRITTY_WINDOW_ID
            set term alacritty
        end
        switch "$term"
            case 'alacritty*'
                set targets alacritty
            case xterm-ghostty
                set targets ghostty
            case '*'
                echo "theme: can't tell which terminal this is ('$term') - use --sync" >&2
                return 1
        end
    end

    set -l name
    if test (count $argv) -gt 0
        set name $argv[1]
    else if contains alacritty $targets; and command -q althemer
        # althemer owns the alacritty side; run it, then read back its choice.
        althemer; or return $status
        set name (string match -rg 'themes/([^/"]+)\.toml' -- (cat $HOME/.config/alacritty/theme.toml 2>/dev/null | string collect))
    else if test "$targets" = ghostty; and command -q fzf
        # fzf stands in for althemer, whose preview only drives alacritty:
        # each highlighted theme is written and signalled for a live preview,
        # and the original is put back if the pick is abandoned.
        set -l orig (cat $ghostty_conf 2>/dev/null | string collect)
        set name (theme -l | fzf --prompt 'ghostty theme> ' \
            --bind "focus:execute-silent(printf 'config-file = themes/%s\n' {} >$ghostty_conf; pkill -USR2 -x ghostty)")
        if test -z "$name"
            printf '%s\n' $orig >$ghostty_conf
            pkill -USR2 -x ghostty >/dev/null 2>&1
            return 1
        end
    else
        echo "theme: no picker installed (althemer/fzf) - pass a name (theme -l to list)" >&2
        return 1
    end

    if test -z "$name"; or not test -f $themes_dir/$name.toml
        echo "theme: unknown theme '$name' (theme -l to list)" >&2
        return 1
    end

    if contains alacritty $targets
        printf '[general]\nimport = ["%s/%s.toml"]\n' $themes_dir $name >$HOME/.config/alacritty/theme.toml
    end

    if contains ghostty $targets
        if test -f $HOME/.config/ghostty/themes/$name
            printf 'config-file = themes/%s\n' $name >$ghostty_conf
            # no-op when ghostty isn't running; never fail the switch over it
            pkill -USR2 -x ghostty >/dev/null 2>&1
        else
            echo "theme: no ghostty theme for '$name' - run scripts/gen-terminal-themes" >&2
        end
    end

    set -l scratch_conf $HOME/.config/tmux/theme-scratch.conf
    if contains ghostty $targets; and test -f $scratch_conf; and tmux has-session -t =scratch 2>/dev/null
        # Drop the old override first: --sync wants scratch back on the global
        # palette, and a new override must not inherit a stale one's leftovers.
        string replace -rf '^set -t =scratch: (?:-F )?(\S+) .*' 'set -u -t =scratch: $1' <$scratch_conf | tmux source-file - 2>/dev/null
    end
    if set -q _flag_sync
        rm -f $scratch_conf
    else if contains ghostty $targets; and test -f $HOME/.config/tmux/themes/$name.conf
        # The palette as scratch-session options: catppuccin's formats that
        # reference #{@thm_*} resolve per session. status-style is baked to
        # literal colours at load, so it is restated from that palette here.
        begin
            string replace -rf '^set -g (@thm_\S+ .*)' 'set -t =scratch: $1' <$HOME/.config/tmux/themes/$name.conf
            echo 'set -t =scratch: -F status-style "bg=#{@thm_mantle},fg=#{@thm_fg}"'
            echo 'set -t =scratch: -F message-style "fg=#{@thm_teal},bg=#{@thm_surface_0},fill=#{@thm_surface_0}"'
            echo 'set -t =scratch: -F message-command-style "fg=#{@thm_teal},bg=#{@thm_surface_0},fill=#{@thm_surface_0}"'
        end >$scratch_conf
        if tmux has-session -t =scratch 2>/dev/null
            tmux source-file $scratch_conf
        end
    end

    if contains alacritty $targets
        if test -f $HOME/.config/tmux/themes/$name.conf
            printf 'source-file ~/.config/tmux/themes/%s.conf\n' $name >$HOME/.config/tmux/theme.conf
            # Re-source the whole config rather than just the theme: catppuccin
            # bakes the @thm_* palette into its module format strings when it
            # loads, so the plugins have to run again for the status line to
            # actually repaint.
            if tmux has-session 2>/dev/null
                tmux source-file $HOME/.tmux.conf >/dev/null 2>&1
            end
        else
            echo "theme: no tmux theme for '$name' - run scripts/gen-terminal-themes" >&2
        end
    end

    echo "theme: $name ("(string join ' + ' $targets)")"
end
