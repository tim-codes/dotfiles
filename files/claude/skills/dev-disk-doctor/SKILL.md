---
name: dev-disk-doctor
description: Read-only audit of the ~/dev workspace for disk pollution — stray upstream git clones nested inside repos, bloated .git dirs, node_modules, Rust target/ and Next.js .next/ build output, plus any large stray files met along the way — ending in a ranked "what, where, size, suggested action" report and a reclaimable total. Reports only; it cleans up nothing unless Tim then approves specific items. Use when Tim says "/dev-disk-doctor", "where has my disk gone", "audit ~/dev for bloat", "find big junk in my repos".
---

# dev-disk-doctor: find disk pollution in ~/dev

Motivating case (2026-10-30): a 5.9 GB untracked clone of upstream
`raspberrypi/firmware` (5.7 GB of it `.git` history) sat inside homelab for two years.

## Output rule

Run silently. Hand the sweep to ONE subagent (`general-purpose`, `model: sonnet`;
no dedicated agent fits a disk audit). Its `du`/`find` output is large and the
conclusion is small, so only the report reaches the main context. Speak mid-run only for
errors. End with the report below.

## Hard rules (restate them in the subagent brief)

- READ-ONLY. Never delete, move or clean anything: no `git gc/prune/clean`,
  `cargo clean`, `pnpm store prune`, `trash` or `rm`. Read-only commands only:
  `du -xsh`, `find -xdev`, `ls`, `stat`, and these git commands: `rev-parse`,
  `status --porcelain`, `count-objects -vH`, `remote get-url`, `submodule status`,
  `log -1 --format=%cs`.
- No network (never fetch). Don't print file contents. Never open `.env*` files.
- A command that seems hung may be waiting on Touch ID: wait, don't kill it.

## Scope

1. **Worktrees are out of scope.** Skip top-level `~/dev/<repo>-<branch>` directories
   whose `.git` is a FILE (worktrunk worktrees), and say so in the report with their
   combined size. Worktree clean-up is a separate concern (`worktree-closedown`). Nested
   worktrees under a repo (e.g. `exxo/h2gc/h2gc-portal-*`, `.claude/worktrees/*`) still get
   sized, because they dominate node_modules, but list them as "worktree, out of scope"
   rather than as a cache to clear.
2. **Nested foreign `.git`:** every `.git` dir or file below a repo's top level. Classify
   each as a registered submodule (`.gitmodules` / `git submodule status`), a worktree
   (`.git` file), a tool cache (`.terraform/modules`) or a **stray clone**. A stray clone
   gets its remote, size, and whether the outer repo tracks, ignores or leaves it untracked.
   A stray clone of an upstream project is "bin, re-clonable; note the remote and commit".
3. **Bloated `.git`:** `git count-objects -vH` per repo; flag size-pack > 1 GB, and
   size-garbage or loose objects worth a gc.
4. **Build caches:** `node_modules`, Rust `target/`, `.next/`. Give the total per type
   and the largest instances. Mark ones in repos idle for over 90 days (last commit
   date). These can all be regenerated.
5. **Incidental:** large (> 500 MB) stray dirs or files met along the way. Examples:
   `.turbo/cache`, `.terraform/providers`, archives/images/dumps (`.zip .tar* .iso .img
   .qcow2 .sql* .dump .mov`). Mention them briefly; don't hunt exhaustively.

Also sweep sub-roots like `~/dev/exxo`, `~/dev/personal` and `~/dev/oss` (repos sit
up to three levels deep). Start with `du -xsh ~/dev` and the top directories at depth 1-2.

## Report: one ranked table plus three lists

Table columns: rank, what, path (`~`-relative), size, category, why it is pollution,
suggested action. Actions: "bin, upstream re-clonable", "`rm -rf .next`", "`cargo
clean`", "delete node_modules (idle)", "`turbo` cache prune", "gitignore", or
"worktree-closedown (out of scope)".

Then:
- **Totals:** per type, plus a realistic reclaimable estimate next to the
  everything-cleared one.
- **Do not bin:** anything that may be unique work or data. That covers a dirty or
  unpushed repo/worktree, uploads or storage dirs, DB dumps, `.env*` neighbours. Say
  why. Client or production data on a laptop is worth flagging on its own.
- **Uncertain:** things that may be wanted.

## If Tim approves clean-up afterwards

Act only on the items he names, one at a time.
- Prefer `trash` (macOS, recoverable) over `rm`.
- Use the tool's own command for caches (`cargo clean` in the crate dir, the turbo prune).
- Before removing a stray clone, record its remote and HEAD commit in the outer repo's
  README, on a branch with a PR (the dotfiles/homelab git workflow).
- Never touch worktrees here; route them to `worktree-closedown`.
- Finish with what was freed (`du` before and after) and a **Follow-up for you** list
  (e.g. empty the Trash, reinstall dependencies before the next build of that repo).
