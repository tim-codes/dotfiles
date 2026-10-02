#!/bin/sh
# Runs TPM for .tmux.conf and leaves a record, because on 2026-10-02 a reboot
# came up with no plugins loaded (no theme, no resurrect, so no continuum
# restore) while every config line after the tpm `run` still applied - and
# TPM itself is silent about failures. Re-running it by hand worked.
#
# - PATH gets the Homebrew prefixes first: at login the server may inherit
#   launchd's bare PATH, and TPM and the plugin scripts call `tmux` by name.
# - Each run appends to ~/.local/state/tmux/tpm-boot.log (trimmed to the last
#   400 lines): when, the environment that matters, TPM's output and exit code.
# - If resurrect's restore key is still unbound afterwards the plugins did not
#   load, so say so in the status line instead of leaving a half-configured
#   tmux looking normal.

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

log_dir="$HOME/.local/state/tmux"
log="$log_dir/tpm-boot.log"
mkdir -p "$log_dir"

{
  echo "=== $(date '+%F %T') tpm run (server $(tmux display -p '#{pid}' 2>/dev/null), up $(uptime | sed 's/.*up //; s/,.*//'))"
  echo "PATH=$PATH"
  echo "SHELL=$SHELL TMUX=$TMUX"
  "$HOME/.tmux/plugins/tpm/tpm"
  echo "tpm exit=$?"
  if tmux list-keys -T prefix 2>/dev/null | grep -q "^bind-key  *-T prefix  *C-r "; then
    echo "plugins: loaded"
  else
    echo "plugins: MISSING (prefix C-r unbound after tpm)"
    # At boot no client is attached yet, so a display-message would be lost:
    # put the warning in the status line, where it stays until a reload that
    # loads the plugins (.tmux.conf resets status-left before this runs).
    tmux set -g status-left \
      "#[fg=red,bold] tmux plugins failed to load: see ~/.local/state/tmux/tpm-boot.log, C-a : rt to retry #[default]"
    tmux set -g status-left-length 120
  fi
} >>"$log" 2>&1

tail -n 400 "$log" >"$log.tmp" 2>/dev/null && mv "$log.tmp" "$log"
exit 0
