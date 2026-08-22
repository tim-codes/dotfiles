---
name: claude-workstation-setup
description: Full disclosure of how Claude Code is set up on Tim's workstations — per-account contexts, shell wrappers, settings/CLAUDE.md fragment merge, the two skill-delivery paths, and where approvals/memory live. Use when asked how the Claude setup/context segregation works, when changing any part of it (claude-sync, settings/CLAUDE.md fragments, skills, plugins), or when a session behaves as if it's in the wrong account, or when adding/updating a global (cross-session) instruction.
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
- `~/.claude-exxo-personal` — OVERLAY, not a third account: the exxo context
  with only the login swapped to the personal subscription, for when exxo
  quota is maxed out. `claude-exxo-personal` pins it; desktop alias
  `claude-d-exxo-personal`. claude-sync builds its settings/CLAUDE.md/skills
  from the SAME exxo fragments (via its `CONTEXTS` name:fragment mapping) and
  symlinks the durable state — `projects/` (transcripts + auto-memory),
  `history.jsonl`, `plugins/`, `file-history`, `plans`, `tasks`, `todos`,
  `paste-cache` — into `~/.claude-exxo`, so `claude-exxo-personal --resume`
  continues the very session that hit the quota wall. Only auth is separate
  (keychain credential keyed by a hash of CLAUDE_CONFIG_DIR, plus the
  per-dir `.claude.json`); first use needs a one-time personal `/login` and
  re-answers per-repo trust prompts. Caveats: claude.ai-side features
  (MCP connectors, cloud sessions, artifacts, ultrareview billing) follow
  the logged-in ACCOUNT, so Exxo-org connectors aren't reachable here —
  connector-heavy sessions stay on real exxo quota; desktop session pickers
  are per user-data dir, so resume across the two profiles via the CLI.
  Never hand-create real files inside this context where a symlink belongs —
  claude-sync warns and leaves them, orphaning that history from exxo.

The legacy default context (`~/.claude` plus the home-level `~/.claude.json`)
is EXPECTED to exist alongside the dedicated ones — launchers that don't
carry the env pin (Cowork-style sessions, tools shelling out to `claude`)
legitimately use it. Note `.claude.json` never follows CLAUDE_CONFIG_DIR: a
pinned run writes `<context>/.claude.json` and leaves the home-level file
untouched. The dedicated contexts simply ignore the default one — its
presence is not an error signal, and nothing here syncs into it.
`claude-default` / `claude-d-default` are the wrappers for using it
deliberately. (The desktop aliases pass `--env CLAUDE_CONFIG_DIR=...`
because LaunchServices does not inherit shell env.)

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

## Global instructions (CLAUDE.md): shared baseline + optional per-account fragment

Same shape as settings, one level simpler. `claude-sync` concatenates
`files/claude/CLAUDE.md.shared` with an optional `files/claude/CLAUDE.md.<account>`
fragment (plain text append, not a jq merge — there's nothing to deep-merge)
and copies the result to `<context>/CLAUDE.md`, copied not symlinked, same
reasoning as settings.json (the file gets hand-edited in place sometimes,
and a symlink would let that land in the repo silently instead of showing up
as drift). Unlike settings, the account fragment is optional: most global
instructions are expected to stay shared, so `CLAUDE.md.personal` /
`CLAUDE.md.exxo` don't need to exist until one account actually needs
something the other shouldn't get.

**Procedure for adding or updating a global instruction:** never write
directly to `~/.claude-personal/CLAUDE.md` or `~/.claude-exxo/CLAUDE.md` —
that's exactly the hand-duplication that created the gap this section fixes
(found 2026-08-18: both contexts had independently hand-copied CLAUDE.md
content with no sync mechanism between them at all). Instead:
1. Decide scope — applies to both accounts (the common case) → edit
   `files/claude/CLAUDE.md.shared`; personal-only or exxo-only → edit (or
   create) `files/claude/CLAUDE.md.personal` / `CLAUDE.md.exxo`.
2. Run `scripts/claude-sync` (or `--diff` first to preview).
3. If a context's `CLAUDE.md` had unmanaged edits, they're backed up to
   `CLAUDE.md.bak-<ts>` before being overwritten — check that backup for
   anything worth promoting into a fragment, same as settings.json drift.

This is also the fix to reach for if an agent (or you) is asked to "record
an instruction so it applies everywhere" — that request means "edit the
repo fragment and sync," not "write the same text into each context file."

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
   Authoring asymmetry (verified against claude-sync): author new skills in
   the personal context or the repo directly. A real directory created under
   `~/.claude-exxo/skills/` works for sessions only until the next
   claude-sync, which ADOPTS it into `files/claude/skills/` — safely in git,
   but personal-only, so it vanishes from the exxo context until promoted
   via `shared_skills()`. (A name the repo already has is warned about and
   left in place.) Org content belongs in the Exxo-Labs/skills repo instead.
2. **Plugins** via marketplaces declared in the settings fragments: exxo
   enables `exxo-common@exxo-skills` (org skills: secret handling, CI runner
   targeting). The marketplace source is the SSH remote
   `git@github.com:Exxo-Labs/skills.git` — SSH, not HTTPS, because the
   background plugin refresh disables git credential helpers and HTTPS fails
   on private repos. Plugin installs are SNAPSHOTS pinned to a commit SHA,
   not live reads: authoring in the skills repo reaches exxo only after the
   change lands on main and `claude plugin update exxo-common@exxo-skills`
   runs under the exxo CLAUDE_CONFIG_DIR (restart the session to apply).
   Changing a marketplace's source in settings does not re-source an
   already-registered context — that takes `plugin marketplace remove` +
   `add`, then `plugin install`.

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
  CLAUDE_CONFIG_DIR. Concrete check: `echo $CLAUDE_CONFIG_DIR` —
  `/Users/tim/.claude-personal` for bare `claude`, `/Users/tim/.claude-exxo`
  for `claude-exxo`, `/Users/tim/.claude-exxo-personal` for
  `claude-exxo-personal`; empty means the legacy default context (fine if
  launched deliberately via `claude-default` or an unpinned tool, wrong if
  an account wrapper was intended).
- A settings or CLAUDE.md change vanished → it was hand-written into a
  context file; promote it into the matching fragment (`settings.<account>.json`
  or `CLAUDE.md.shared`/`CLAUDE.md.<account>`) and re-run `claude-sync`.
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
homelab #76, Linear ENG-20; CLAUDE.md shared+fragment sync added 2026-08-18
after two independently hand-duplicated copies were found with no sync
mechanism between them. Deferred follow-ups tracked in
`files/claude/README.md`.
