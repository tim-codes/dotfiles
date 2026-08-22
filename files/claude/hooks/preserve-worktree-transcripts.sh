#!/bin/bash
# Safety net for Claude session transcripts hosted in git worktrees.
#
# Wired in settings.shared.json as a SessionEnd hook (coverage: fires however
# the worktree later dies — harness cleanup, Bash `git worktree remove`, the
# user's own shell) and a PreToolUse hook on ExitWorktree (belt-and-braces).
# If the session's cwd is inside a LINKED worktree, copy that cwd-slug's
# transcripts under <ctx>/projects/ to the slug of the corresponding path in
# the primary checkout, no-clobber. Copy, not move: the session may still be
# live, and a hook must never mutate transcripts in place — so the copies
# keep their worktree cwd fields and are inspect-grade, not clean-resume
# grade. The worktree-closedown skill remains the proper closedown (it moves,
# rewrites cwd paths, then removes the worktree); this hook only makes
# forgetting it non-fatal.
#
# FAIL-OPEN BY CONSTRUCTION: a PreToolUse hook that exits non-zero can block
# the tool call, and no bug here may ever break a worktree flow — every path
# out of this script is exit 0, errors included. Corollary: a silent failure
# here means silent non-protection, which is why the skill + CLAUDE.md
# instruction stay load-bearing. Known accepted gaps: paths >200 chars get a
# truncate+hash slug we don't reproduce, and sessions killed hard never fire
# SessionEnd.
exec 2>/dev/null
set +e

# Session cwd from the hook payload on stdin; fall back to $PWD.
cwd="$(jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"

git_dir="$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)" || exit 0
common_dir="$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)" || exit 0
[ -n "$git_dir" ] && [ -n "$common_dir" ] || exit 0
# In the primary checkout (or not a repo at all) the two coincide — the 99%
# case, exit fast.
[ "$git_dir" = "$common_dir" ] && exit 0

worktree_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
primary_root="$(cd "$(dirname "$common_dir")" 2>/dev/null && pwd)" || exit 0
[ -n "$worktree_root" ] && [ -d "$primary_root" ] || exit 0

# Map the session cwd (which may be a subdir of the worktree) onto the same
# relative path under the primary checkout.
case "$cwd" in
    "$worktree_root") mapped="$primary_root" ;;
    "$worktree_root"/*) mapped="$primary_root${cwd#"$worktree_root"}" ;;
    *) exit 0 ;;
esac

slugify() { printf '%s' "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }

ctx="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
src="$ctx/projects/$(slugify "$cwd")"
dst="$ctx/projects/$(slugify "$mapped")"
[ -d "$src" ] || exit 0
[ "$src" = "$dst" ] && exit 0

mkdir -p "$dst" || exit 0
# -n: never overwrite — an already-relocated (rewritten) file wins over the
# raw safety copy, and re-runs are no-ops.
cp -Rpn "$src"/. "$dst"/ || true
exit 0
