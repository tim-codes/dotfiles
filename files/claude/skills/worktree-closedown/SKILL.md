---
name: worktree-closedown
description: Close down a finished git worktree WITHOUT losing the Claude session transcripts that ran inside it — relocate them into the primary checkout's project slug first, then remove the worktree. Use whenever a work stream in a worktree is finished and the worktree should go away, when Claude Code's built-in prompt offers to clean up a worktree (decline it and run this instead), or when asked to recover/inspect sessions from an already-removed worktree.
---

# Worktree closedown: preserve transcripts, then remove

## Why this exists

Transcripts for sessions launched *inside* a worktree live under that
worktree's own cwd slug in `<CLAUDE_CONFIG_DIR>/projects/`. Removing the
worktree orphans them: the `--resume` picker is keyed to the current cwd, so
from the primary checkout those sessions simply don't appear, and the
periodic transcript cleanup (`cleanupPeriodDays`, default 30 days) purges
them eventually — observed on this machine as an emptied slug dir. Claude
Code's built-in "clean up the worktree?" prompt does none of this
preservation. **Decline that prompt** and follow this procedure, which
merges the transcripts into the primary checkout's slug so they stay
inspectable and resumable, then removes the worktree.

(Sessions that started in the primary checkout and only *entered* a worktree
mid-session — EnterWorktree, `isolation: "worktree"` agents — already
transcribe under the primary slug and need nothing from this skill.)

A fail-open safety net also exists: the `preserve-worktree-transcripts.sh`
hook (SessionEnd, plus PreToolUse on ExitWorktree — see
settings.shared.json) copies a worktree-hosted session's transcripts to the
primary slug automatically. Those raw copies still carry the worktree's cwd
fields, so they're inspectable but not cleanly resumable — this skill's
relocate-and-rewrite remains the proper closedown; the hook only makes
forgetting it non-fatal.

**With worktrunk, prefer `wt remove <branch>` (or `wt merge`).** Its
pre-remove hook (`src/.config/worktrunk/config.toml` in dotfiles) runs
`worktree-relocate-transcripts`, which is steps 1-3 below scripted across
every context dir, and blocks the removal if it fails or if a claude
session is still running in the worktree. Claude's own worktrees go the same
way via the worktrunk plugin's WorktreeRemove hook. The manual procedure
below remains for repos/machines without worktrunk, for recovering an
already-removed worktree, and for the Desktop caveat (step 4), which the
script only reports.

## Procedure

Definitions: `W` = absolute worktree path, `P` = absolute primary checkout
path (both from `git worktree list`), `CTX` = the session's config dir
(`$CLAUDE_CONFIG_DIR`, fall back to `~/.claude`).

1. **Find the worktree's slug dir(s).** The slug is the cwd path with every
   non-alphanumeric character replaced by `-`. Don't reimplement that
   perfectly — list `$CTX/projects/` and match: the dir whose name equals
   slug(`W`), plus any dir whose name starts with slug(`W`)`-` (sessions
   launched from a subdirectory of the worktree). Nothing found → no
   sessions ever ran there; skip to step 5.

2. **Relocate each session into the primary slug.** Target dir is
   slug(`P`) (or slug of the matching subpath under `P`); `mkdir -p` it if
   new. For every entry in the source slug dir, move `<uuid>.jsonl` AND any
   sidecar dir named `<uuid>/` into the target, overwriting a same-uuid
   entry already there: that's the raw safety copy made by the
   `preserve-worktree-transcripts.sh` hook (SessionEnd / ExitWorktree,
   see settings.shared.json), and the relocated, path-rewritten version
   from this procedure supersedes it. Distinct sessions can't collide —
   uuids are unique.

3. **Rewrite embedded paths.** Each moved `.jsonl` records the worktree path
   in `"cwd"` fields (and possibly other path strings). Rewrite `W` → `P`
   with an exact-string, non-regex replacement, e.g.
   `perl -pi -e 's/\Q<W>\E/<P>/g' <file>` — JSON-safe because both are
   plain absolute paths with no characters needing JSON escaping.

4. **Desktop app caveat.** If any of these sessions ran in Claude Desktop,
   the desktop session record (`~/Library/Application Support/<user-data-dir>/
   claude-code-sessions/**/local_*.json`) also embeds `cwd`/`originCwd` and
   wins on resume — update it with the app quit, per the
   claude-workstation-setup skill. CLI-only sessions need nothing more.

5. **Check submodules for unsaved work** (skip if the repo has none, i.e. no
   `.gitmodules`). A worktree's submodules are separate clones, so the
   worktree's own `git status` can look clean while a submodule holds
   uncommitted edits or local-only commits, and removing the worktree
   destroys both. From `W`:
   `git submodule foreach --recursive 'git status --porcelain; git log --oneline --branches --not --remotes'`.
   Any output other than the `Entering '<path>'` lines means stop: push or
   discard that work deliberately first. This applies
   to the `wt remove` route too, since worktrunk doesn't check submodules
   separately.

6. **Remove the worktree.** With worktrunk, `wt remove <branch>` handles
   submodules itself (verified on wt 0.79). Without it, run
   `git -C <P> worktree remove <W>` from the primary checkout. If that fails
   with `working trees containing submodules cannot be moved or removed`,
   and step 5 was clean, clear the submodules first and retry:
   `git -C <W> submodule deinit --all --force`, then
   `rm -rf "$(git -C <W> rev-parse --absolute-git-dir)/modules"`, then the
   same `worktree remove` without `--force`. The `modules` dir under the
   worktree's own git dir (`<P>/.git/worktrees/<name>/modules`) holds the
   submodule clones, and git refuses while it exists. `deinit` alone isn't
   enough (verified on git 2.50). Prefer this to `--force`, which would also
   discard any uncommitted state in the worktree itself; use `--force` only
   for genuinely disposable state, and say so. Delete the branch only if its
   PR is merged: `git -C <P> branch -d <branch>`. A squash-merged branch
   needs `-D`, after confirming the PR is merged. Never `rm -rf` a worktree
   directly: git keeps metadata in `<P>/.git/worktrees/` that
   `git worktree remove` cleans up (`git worktree prune` repairs the
   aftermath of a raw delete).

7. **Report** what was preserved (session uuids, target slug) and what was
   removed, so the closedown is auditable from the conversation.

## Recovering sessions from an already-removed worktree

Same as steps 1–4: the orphaned slug dir usually still exists under
`$CTX/projects/` (until `cleanupPeriodDays` catches it) even though the
worktree is gone — find it by the old path's slug and relocate. If the slug
dir is already empty, the transcripts are gone; say so plainly.
