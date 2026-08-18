---
name: dotfiles-repo
description: How to operate Tim's dotfiles repo (~/dev/dotfiles) from any session — where a workstation dependency install gets persisted (Homebrew/cargo/pnpm manifest arrays), the Stow symlink mechanism, the worktree rule for branch work, and common maintenance commands (restow, deps-up). Use whenever a task installs a system/workstation dependency that needs persisting per the global instruction, needs to edit a Stow-managed config file, or otherwise needs to act on dotfiles from outside that repo.
---

# Dotfiles: operating the repo from any session

This is a first tier, not the full picture — enough to act correctly on
dotfiles from a session that isn't already inside it, without reproducing
everything `~/dev/dotfiles/CLAUDE.md` already documents in depth. Read that
file directly for anything past what's here: full directory structure,
shell config load order, platform detection, and more. It's the cross-
account companion to the global "installing a missing dependency on the
workstation" instruction in particular — the *how*, kept here rather than
in `CLAUDE.md.shared`, because the concrete manifest locations change over
time and any session may need to act on them, not just ones already inside
`~/dev/dotfiles`.

**Scope check first:** this is for the local macOS workstation only. A
dependency needed on a homelab server (zima, ragnar, ...) is not a
workstation install — that goes through `~/dev/homelab` as idempotent
config instead (an Ansible playbook/role), a different repo and mechanism
entirely.

## Where a workstation dependency install gets persisted

All of these are plain arrays in `zsh` scripts under `~/dev/dotfiles/scripts/`
— add the new entry, don't restructure the script:

| Kind of dependency | File | Array |
|---|---|---|
| Homebrew formula (CLI tool) | `scripts/brew-update` | `brewDeps` |
| Homebrew cask (GUI app) | `scripts/brew-update` | `brewCasks` |
| Cargo crate, published | `scripts/cargo-update` | `cargoDeps` |
| Cargo crate, git-only (unpublished) | `scripts/cargo-update` | `cargoGitDeps` (repo URL) |
| pnpm global package | `scripts/pnpm-globals` | `packages` |

A one-line comment above the entry explaining *why* it's there (like the
existing entries do) is the house style — see any current entry in these
files for the pattern. If a needed dependency doesn't fit any of these
(e.g. `apt`, a language ecosystem with no manifest here yet, a one-off
installer), that's a gap in the mechanism itself — surface it rather than
inventing a new ad-hoc script to route around it.

None of these scripts *run* on their own after editing — the entry takes
effect machine-wide the next time `scripts/brew-update` / `cargo-update` /
`pnpm-globals` runs (directly, or via `src/bin/deps-up`, which chains all
three plus nvm/npm). If the dependency is needed *now*, install it directly
first (per the global instruction), then add the manifest entry separately
so the persisted state matches what's actually on the machine.

## Other common operations

- **Added/changed a file under `src/`?** Run `stow --target ~ src` from
  `~/dev/dotfiles` so Stow's symlinks pick it up — without this the new file
  exists in the repo but nothing on the machine points at it yet. There's a
  `restow` shortcut for this, but it's a **fish function**
  (`src/.config/fish/common.fish`); Claude Code sessions run in zsh (see the
  project `CLAUDE.md`), so it won't resolve there — use the `stow` command
  directly.
- **Applying all pending workstation-dependency manifests at once** (after
  editing one, or just to catch up a machine): `~/dev/dotfiles/src/bin/deps-up`
  — chains `brew-update`, `cargo-update`, `pnpm-globals`, and an nvm/npm
  update. Individual scripts (`scripts/brew-update` etc.) can be run alone
  when only one manifest changed. `brew-update` throttles itself to once per
  20 minutes via a timestamp check, so back-to-back runs are cheap to call
  and safe not to skip.
- **Bootstrapping a new machine** is out of scope for a mid-task session —
  it's `scripts/bootstrap` (curl-able from `main`) → `scripts/init`, and
  covered in full in the project `CLAUDE.md`. Don't reach for it as a side
  effect of an unrelated task.

## Branch work here requires a worktree

Stow symlinks live config (`~/.zshrc`, `~/.config/fish/*`, the per-account
`~/.claude-*/CLAUDE.md`/`settings.json` that `scripts/claude-sync` reads
from here, etc.) straight into this checkout's `src/` by path, not by ref.
Checking out a branch in the primary `~/dev/dotfiles` checkout changes every
one of those live files immediately, machine-wide — including mid-edit
state. Never do that. Instead:

```
git worktree add ../dotfiles-<branch> <branch>   # or -b <branch> for a new one
```

and do the work there. The primary checkout stays parked on `main`, so the
symlinks keep resolving to `main`'s content for as long as the branch is
being worked on. Full detail: `~/dev/dotfiles/CLAUDE.md`, "Editing
Workflow" section.

## Shipping the change

Standard shared git-workflow instruction applies as-is: branch (in a
worktree, per above), logical commits, push with a draft PR at a sensible
checkpoint, squash-merge only when explicitly directed. Dotfiles is a
personal repo, not a production-stage Exxo one, so the mandatory-human-review
exception doesn't apply here — the default flow is the whole story.
