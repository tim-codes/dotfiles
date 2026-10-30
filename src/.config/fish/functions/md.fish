# Render a markdown file (or stdin) for reading in the terminal.
#
# Two renderers, because neither wins on everything: glow styles prose well but
# pads every table column to the same width, which turns a wide glossary into
# whitespace; mdcat sizes table columns to their content. So: tables -> mdcat
# at the full terminal width, everything else -> glow at the prose measure from
# ~/.config/glow/glow.yml (capped by the terminal width, which `tput cols`
# reports live -- fish's own $COLUMNS goes stale after a resize).
#
# Paging is deliberately NOT `| bat`. Both renderers drop all colour the moment
# stdout is a pipe (glow has no force-colour env at all in 3.0.0), so piping
# anywhere hands the pager plain text -- and bat then repaints it in its own
# plain-text theme, which is why that combination looked washed out. mdcat has
# --ansi to force styling through a pipe, so it can feed `less -R`; glow can't,
# so it renders straight to the terminal and gets its own pager (-p) only when
# the output is too long to fit on screen.
#
#   md FILE...      render files
#   cmd | md        render stdin
#   md -g FILE      force glow      md -m FILE   force mdcat
#   md -w 90 FILE   fixed width
#
# Piping md's own output (md FILE | rg foo) yields uncoloured, unpaged text.
function md -d "Pretty-print markdown (glow for prose, mdcat for tables)"
    argparse g/glow m/mdcat w/width= -- $argv
    or return

    # stdin is drained to a temp file up front, so every renderer below reads
    # from a file and gets </dev/null -- glow otherwise blocks on an inherited
    # stdin in non-interactive contexts
    set -l files $argv
    set -l stdin_tmp
    if test (count $files) -eq 0
        set stdin_tmp (mktemp -t md.XXXXXX)
        cat >$stdin_tmp
        set files $stdin_tmp
    end

    set -l cols (tput cols 2>/dev/null; or echo 100)
    set -l rows (tput lines 2>/dev/null; or echo 40)

    # a table row is the only markdown construct that needs the full width
    set -l use_mdcat 0
    if set -q _flag_mdcat
        set use_mdcat 1
    else if not set -q _flag_glow
        and command -q mdcat
        and grep -qE '^ *\|.*\|' $files 2>/dev/null
        set use_mdcat 1
    end

    if test $use_mdcat -eq 1
        set -l w $_flag_width
        test -n "$w"; or set w $cols
        if isatty stdout
            # --ansi keeps the styling alive through the pipe; -F drops straight
            # back to the prompt when it all fits on one screen
            mdcat --ansi --columns $w $files </dev/null | less -R -F -X
        else
            mdcat --columns $w $files </dev/null
        end
    else
        set -l w $_flag_width
        test -n "$w"; or set w (math "min($cols, 100)")
        if not isatty stdout
            glow -w $w $files </dev/null
        else if test (glow -w $w $files </dev/null | wc -l) -gt $rows
            # too long for the screen, and glow only stays colourful when it
            # owns the terminal -- so let it page itself (q to quit)
            glow -p -w $w $files
        else
            glow -w $w $files </dev/null
        end
    end

    test -n "$stdin_tmp"; and rm -f $stdin_tmp
end
