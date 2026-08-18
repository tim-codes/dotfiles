#!/bin/bash
# PreToolUse hook (Write|Edit): guards the dotfiles PRIMARY checkout from
# direct edits. Stow symlinks live config straight into this checkout's
# src/ by path, not by ref — an in-place edit there is live on the machine
# immediately, before any commit or branch switch. See dotfiles CLAUDE.md,
# "Editing Workflow", and the dotfiles-repo skill.
set -euo pipefail

primary="$HOME/dev/dotfiles"

file_path="$(jq -r '.tool_input.file_path // empty')"
[ -z "$file_path" ] && exit 0

# Resolve to an absolute, symlink-real path even if the file doesn't exist
# yet (Write creating a new file) — resolve the parent dir and reattach the
# leaf name rather than requiring the target itself to exist.
dir="$(dirname -- "$file_path")"
base="$(basename -- "$file_path")"
abs_dir="$(cd -- "$dir" 2>/dev/null && pwd -P)" || exit 0
resolved="$abs_dir/$base"

case "$resolved" in
  "$primary"/*)
    # Only warn if $primary is itself the real checkout (a .git DIRECTORY),
    # not a linked worktree (whose .git is a FILE) — worktrees are exactly
    # where this kind of edit is supposed to happen.
    if [ -d "$primary/.git" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"This edits the dotfiles PRIMARY checkout (%s) directly. Stow symlinks make this live on the machine immediately, before any commit. Use a git worktree instead (git worktree add ../dotfiles-<branch> <branch>) unless this specific edit is an explicitly-directed direct-to-main change."}}' "$primary"
    fi
    ;;
esac
exit 0
