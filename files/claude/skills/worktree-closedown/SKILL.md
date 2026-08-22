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
   sidecar dir named `<uuid>/` into the target. A uuid collision in the
   target should never happen (uuids are unique) — if one somehow does, stop
   and surface it rather than overwrite.

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

5. **Remove the worktree.** From the primary checkout:
   `git -C <P> worktree remove <W>` (add `--force` only for genuinely
   disposable uncommitted state, and say so). Delete the branch only if its
   PR is merged: `git -C <P> branch -d <branch>`. Never
   `rm -rf` a worktree directly — git keeps metadata in
   `<P>/.git/worktrees/` that `git worktree remove` cleans up (`git worktree
   prune` repairs the aftermath of a raw delete).

6. **Report** what was preserved (session uuids, target slug) and what was
   removed, so the closedown is auditable from the conversation.

## Recovering sessions from an already-removed worktree

Same as steps 1–4: the orphaned slug dir usually still exists under
`$CTX/projects/` (until `cleanupPeriodDays` catches it) even though the
worktree is gone — find it by the old path's slug and relocate. If the slug
dir is already empty, the transcripts are gone; say so plainly.
