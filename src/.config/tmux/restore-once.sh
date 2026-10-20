#!/bin/sh
# Restores the last tmux-resurrect snapshot once per server (replacing
# tmux-continuum's auto-restore). Started by .tmux.conf (run-shell -b, after
# the tpm run line) only while neither @home_restore_done nor
# @home_restore_started is set, so a config reload never restores twice.
#
# Why not continuum: on the 2026-10-17 boot its restore silently never ran -
# it skips restoring whenever it counts more than one other `tmux` process of
# this user at startup, which the LaunchAgent and the ghostty dropdown starting
# tmux side by side can trip. The server then ran 2.5 days holding only
# `scratch`, continuum kept autosaving that, and the 2026-10-20 reboot
# restored only scratch. Here there is no other-server heuristic, and
# tmux-home's daemon autosaves only once @home_restore_done is set, so a
# server that never restored can't overwrite `last` either.
#
# - Resurrect's post-restore-all hook (in .tmux.conf) sets @home_restore_done
#   when a restore completes. A restore that fails part way leaves it unset:
#   autosave stays paused and status-left says so.
# - No snapshot at all (a fresh machine) means nothing to protect: set the flag
#   here so autosave starts.
# - Resurrect not loaded (TPM failed, see tpm-run.sh): clear the started guard
#   again, so the `rt` reload that fixes the plugins also restores.
# - ~/tmux_no_auto_restore halts it, as it did continuum. The flag stays
#   unset: save by hand (prefix C-s) once the server holds what should be kept.
#
# Mirrors continuum_restore.sh otherwise: a 1s head start for tmux, then
# resurrect's restore script from @resurrect-restore-script-path. A session
# created alongside (LaunchAgent / dropdown `scratch`) is fine: resurrect
# keeps panes that already exist, and only when the whole server is a single
# pane does it replace that pane with the snapshot's - same as under continuum.

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

[ -e "$HOME/tmux_no_auto_restore" ] && exit 0

# give tmux some time to start and source all the plugins (continuum's delay)
sleep 1

restore_script="$(tmux show-option -gqv @resurrect-restore-script-path)"
if [ -z "$restore_script" ] || [ ! -x "$restore_script" ]; then
  tmux set-option -gu @home_restore_started
  exit 0
fi

# Resurrect's own resolution (scripts/helpers.sh): @resurrect-dir with ~,
# $HOME and $HOSTNAME expanded, else ~/.tmux/resurrect if it exists, else
# $XDG_DATA_HOME/tmux/resurrect.
if [ -d "$HOME/.tmux/resurrect" ]; then
  dir="$HOME/.tmux/resurrect"
else
  dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
fi
opt="$(tmux show-option -gqv @resurrect-dir)"
[ -n "$opt" ] && dir="$(echo "$opt" | sed "s,\$HOME,$HOME,g; s,\$HOSTNAME,$(hostname),g; s,\~,$HOME,g")"

if [ -f "$dir/last" ]; then
  "$restore_script"
else
  tmux set-option -g @home_restore_done 1
fi
