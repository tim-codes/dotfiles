#!/bin/sh
# tmux-resurrect post-save-layout hook: stop a snapshot from losing sessions.
#
# On 2026-10-20 a reboot came back without `main`: continuum autosaved ~80s
# before power-off, by which point shutdown had already killed main's panes,
# so the newest snapshot (the one `last` points at, the one restore uses) held
# only `scratch`. A save taken while things are being torn down looks exactly
# like a deliberate kill-session, so tell them apart by time instead:
#
# - Resurrect runs this hook with the new snapshot's path before it repoints
#   `last`, so `last` is still the previous snapshot here. Any session in the
#   previous snapshot but missing from the new one has its pane/window lines
#   copied forward into the new file - unless it's been deliberately removed.
# - main and scratch are pinned: always carried forward, never dropped.
# - Any other session is dropped only once it has been missing for GRACE
#   seconds on the same tmux server that last saw it alive. Shutdown never
#   lasts that long, a kill-session you meant does (two 5-min autosaves).
#   Missing from a different server (a restart whose restore didn't bring it
#   back) means it was never closed on purpose: carried indefinitely.
#
# Last-seen state: ~/.local/state/tmux/session-seen.tsv (name, server, epoch).
# Decisions are logged to ~/.local/state/tmux/resurrect-guard.log.

new="$1"
[ -f "$new" ] || exit 0

PINNED="main scratch"
GRACE=900

state_dir="$HOME/.local/state/tmux"
seen="$state_dir/session-seen.tsv"
log="$state_dir/resurrect-guard.log"
mkdir -p "$state_dir"
touch "$seen"

prev="$(dirname "$new")/last"
[ -e "$prev" ] && prev="$(cd "$(dirname "$prev")" && pwd -P)/$(readlink "$prev")"
[ -f "$prev" ] && [ "$prev" != "$new" ] || prev=""

now=$(date +%s)
server=$(tmux display -p '#{pid}:#{start_time}' 2>/dev/null)

sessions_in() { awk -F'\t' '$1 == "pane" { print $2 }' "$1" | sort -u; }

# Everything alive in this snapshot was seen just now on this server.
live=$(sessions_in "$new")
{
  printf '%s\n' "$live" | awk -v s="$server" -v t="$now" 'NF { print $0 "\t" s "\t" t }'
  printf '%s\n' "$live" | awk -F'\t' 'NR == FNR { live[$1]; next } !($1 in live)' - "$seen"
} >"$seen.tmp" && mv "$seen.tmp" "$seen"

[ -n "$prev" ] || exit 0

# Session names may contain spaces: split the loop below on newlines only.
IFS='
'

for s in $(sessions_in "$prev" | awk -F'\t' 'NR == FNR { if ($1 == "pane") alive[$2]; next } !($0 in alive)' "$new" -); do
  reason=""
  case " $PINNED " in *" $s "*) reason="pinned" ;; esac
  if [ -z "$reason" ]; then
    rec=$(awk -F'\t' -v n="$s" '$1 == n' "$seen")
    rec_server=$(printf '%s' "$rec" | cut -f2)
    rec_time=$(printf '%s' "$rec" | cut -f3)
    if [ -z "$rec" ]; then
      # Never recorded (the guard is newer than the session): start its grace
      # period now rather than guess.
      printf '%s\t%s\t%s\n' "$s" "$server" "$now" >>"$seen"
      reason="no last-seen record"
    elif [ "$rec_server" != "$server" ]; then
      reason="last seen on another server ($rec_server)"
    elif [ $((now - rec_time)) -lt "$GRACE" ]; then
      reason="missing $((now - rec_time))s < ${GRACE}s"
    fi
  fi
  if [ -n "$reason" ]; then
    awk -F'\t' -v n="$s" '($1 == "pane" || $1 == "window" || $1 == "grouped_session") && $2 == n' "$prev" >>"$new"
    echo "$(date '+%F %T') $(basename "$new"): kept $s from $(basename "$prev") - $reason" >>"$log"
  else
    awk -F'\t' -v n="$s" '$1 != n' "$seen" >"$seen.tmp" && mv "$seen.tmp" "$seen"
    echo "$(date '+%F %T') $(basename "$new"): dropped $s - missing $((now - rec_time))s on this server" >>"$log"
  fi
done

tail -n 400 "$log" >"$log.tmp" 2>/dev/null && mv "$log.tmp" "$log"
exit 0
