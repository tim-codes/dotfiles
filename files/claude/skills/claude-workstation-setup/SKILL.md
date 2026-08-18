---
name: claude-workstation-setup
description: Full disclosure of how Claude Code is set up on Tim's workstations — per-account contexts, shell wrappers, settings fragment merge, the two skill-delivery paths, and where approvals/memory live. Use when asked how the Claude setup/context segregation works, when changing any part of it (claude-sync, settings fragments, skills, plugins), or when a session behaves as if it's in the wrong account.
---

# How Claude Code is set up on these workstations

This skill is the durable, cross-account description of the setup. It is
delivered to every context by design, so a work session may name personal
homelab facts (op-shim, zima/ragnar) — that is meta-information about the
segregation, deliberate, and fine on Tim's own machines. Authoritative
sources: `scripts/claude-sync` and `files/claude/README.md` in the dotfiles
repo — prefer reading those before modifying anything they govern.

## Contexts: one per account, selected by CLAUDE_CONFIG_DIR

- `~/.claude-personal` — personal account. Bare `claude` (zsh/fish wrapper)
  pins it; desktop alias `claude-d-personal`.
- `~/.claude-exxo` — work (Exxo) account. `claude-exxo` pins it; desktop
  alias `claude-d-exxo`.

The legacy default `~/.claude` was retired 2026-08-17. If it ever reappears,
something launched Claude without the env pin (the desktop aliases pass
`--env CLAUDE_CONFIG_DIR=...` because LaunchServices does not inherit shell
env) — find the env-less launcher and fix it; do not treat the stray dir as
normal. `claude-default` / `claude-d-default` are the one sanctioned way to
recreate it deliberately.

`~/claude` is a WORKSPACE, not config: wrappers auto-cd into it when
launched from `~` or a context dir. Contexts are created by
`scripts/claude-contexts`; wrappers live in dotfiles `src/.zshrc` and
`src/.config/fish/`.

## Settings: shared + per-account fragments, merged by claude-sync

`scripts/claude-sync` builds each context's `settings.json` from
`files/claude/settings.shared.json` deep-merged with
`settings.<account>.json` (jq `'.[0] * .[1]'`, account fragment wins, nested
objects like `enabledPlugins` merge key-wise), then COPIES the result in —
never symlinks, because Claude Code writes through settings.json constantly
and a symlink kept the repo dirty. Drift is backed up to
`settings.json.bak-<ts>` and promoted by hand; `claude-sync --diff` shows it.

Consequence: never hand-edit `~/.claude-*/settings.json` for anything meant
to last — it reverts on the next sync. Put it in the right fragment instead.
Account-specific keys (the exxo-skills marketplace, its plugin) live only in
`settings.exxo.json`; `~/.claude-personal` must never receive Exxo config.

## Skills reach a context by exactly two paths

1. **Dotfiles skills** (`files/claude/skills/`, this skill included):
   personal gets a whole-directory symlink (`~/.claude-personal/skills` IS
   the repo dir — author a skill in place and it lands in git). exxo gets a
   REAL directory of per-skill symlinks curated by claude-sync against an
   allow list: only repo skills named in `shared_skills()` in
   `scripts/claude-sync` get linked in (currently just
   `claude-workstation-setup`). Every other repo skill is personal-only by
   default and must be explicitly promoted — add its name to
   `shared_skills()` to make it cross-account.
2. **Plugins** via marketplaces declared in the settings fragments: exxo
   enables `exxo-common@exxo-skills` (org skills: secret handling, CI runner
   targeting). Until Exxo-Labs/skills#2 merges, the marketplace points at the
   local checkout `~/dev/exxo/skills`; after that it should be the SSH remote
   (`git@github.com:Exxo-Labs/skills.git` — background plugin refresh
   disables git credential helpers, so HTTPS fails on private repos).

The allow-list replaced an earlier exclusion list, which failed open: every
new personal skill had to remember to opt itself out of the exxo context.
The motivating case was `run-with-secrets`: the repo's copy is homelab
guidance (op-shim, Ansible, zima/ragnar) and the exxo-common plugin ships its
own Exxo `run-with-secrets` (agent/run + agent.env). Verified 2026-08-18:
without an exclusion, BOTH loaded at once in the exxo context, which risked
an Exxo session following homelab credential guidance. Under the allow-list,
`run-with-secrets` is simply absent from `shared_skills()`, so exxo's
curated dir never contains the repo copy — leaving only
`exxo-common:run-with-secrets` there, while personal keeps the homelab one.
When promoting a skill to cross-account, check the plugin side for a name
collision first.

## What is deliberately NOT shared or synced

- **Permission approvals** — per repository, in `.claude/settings.local.json`
  at the repo root, untouched by claude-sync.
- **Auto-memory** — per context, under `<context>/projects/<cwd-slug>/memory/`.
  Kept segregated on purpose (work/personal leakage); durable architecture
  facts belong here in this skill instead.
- **Login state** (`.claude.json`), sessions, history — per context.

## Quick diagnosis

- Session sees Exxo skills in personal (or vice versa) → wrong
  CLAUDE_CONFIG_DIR; check which wrapper launched it.
- A settings change vanished → it was hand-written into a context file;
  promote it into a fragment and re-run `claude-sync`.
- Two skills with one name → check both delivery paths; fix by editing
  `shared_skills()` in `claude-sync` (repo skills are personal-only unless
  named there), not by hand-deleting links.
- Moving an existing session to a new cwd takes three edits with the desktop
  app quit: move the transcript under the new cwd-slug in
  `<context>/projects/`, rewrite its embedded `"cwd":` fields, and update
  `cwd`/`originCwd` in the desktop session record
  (`~/Library/Application Support/<user-data-dir>/claude-code-sessions/**/
  local_*.json`) — the desktop record wins on resume.

History/references: dotfiles PR #17 (fragment split + exxo curation),
homelab #76, Linear ENG-20. Deferred follow-ups tracked in
`files/claude/README.md`.
