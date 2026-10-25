---
name: claude-workstation-setup
description: Full disclosure of how Claude Code is set up on Tim's workstations — per-account contexts, shell wrappers, settings/CLAUDE.md fragment merge (incl. the global permission allow set and deny floor), the repo-config audit hook, repo-managed MCP servers, the two skill-delivery paths (including vendored upstream skills), and where approvals/memory live. Use when asked how the Claude setup/context segregation works, when changing any part of it (claude-sync, settings/CLAUDE.md/MCP fragments, skills, plugins), or when a session behaves as if it's in the wrong account, or when adding/updating a global (cross-session) instruction.
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
- `~/.claude-exxo-openrouter` — FOURTH context, a worker sandbox: the exxo
  fragments plus `settings.overlay.exxo-openrouter.json`, running Claude Code
  against OpenRouter (model `moonshotai/kimi-k3`, "K3") instead of an Anthropic
  subscription. Built for unattended or batch jobs; it is not a way to reach
  Exxo's connectors. Unlike `exxo-personal` it shares almost nothing (see
  "Sharing" below) and carries extra guard rails (see "The OpenRouter
  overlay"). `claude-sync` builds it via `exxo-openrouter:exxo` in `CONTEXTS`
  and `scripts/claude-contexts` creates the directory. Run `claude-sync` ONLY
  from the primary checkout (`~/dev/dotfiles`): a sync run from a worktree
  would deploy that branch's fragments to every live context, and the
  deployed hook commands reference the primary checkout's scripts.

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

One exception to "account fragment wins": the permission rule arrays
(`permissions.allow`/`deny`/`ask`) are CONCATENATED across the two fragments
(shared first, duplicates dropped — `SETTINGS_MERGE` in claude-sync), because
jq's `*` replaces arrays and the exxo grants would otherwise wipe the shared
set. That is where the global permissions live (added 2026-10-23):
`settings.shared.json` carries the read-only allow set (git/gh read
subcommands, `just --list`, `WebSearch`, GitHub `WebFetch`,
`mcp__ide__getDiagnostics`) and the **deny floor** (`op read`, `--reveal`,
`--show-secrets`, `pulumi`/`esc env open`, `gcloud secrets versions access`,
each also as `* <cmd>` so a later segment matches; `Read` of `.claude.json`
and `.credentials.json`); `settings.exxo.json` adds the Exxo read-only cloud
grants (`gcloud * list/describe`, `pulumi preview/whoami/stack ls/stack
output`, `agent-tooling:*`). Deny is evaluated before allow across every
scope, so no repo file can loosen the floor. Repos keep only repo-specific
grants — the conventions are the `claude-repo-config` skill.
`tests/claude-sync-permissions.sh` checks the merge.

### The OpenRouter overlay (`exxo-openrouter`)

`files/claude/settings.overlay.exxo-openrouter.json` is a third layer on top
of `shared * exxo`, applied only to this context (naming: `settings.overlay.
<name>.json`, keyed by context name, not account fragment). It carries:

- **env**: `ANTHROPIC_BASE_URL` (OpenRouter), an EMPTY `ANTHROPIC_API_KEY`
  (so no Anthropic credential is ever used), every tier variable
  (`ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`) and
  `CLAUDE_CODE_SUBAGENT_MODEL` all set to `moonshotai/kimi-k3`, and
  `ENABLE_TOOL_SEARCH=false`. One session has one backend, hence the
  subagent-model exception to the global "unset" rule in `CLAUDE.md.shared`.
- **Key helper**: `apiKeyHelper` runs `scripts/claude-openrouter-key`, which
  reads the local file `~/keys/openrouter.key` (file mode 0600, directory
  0700) and refuses symlinks, loose modes and malformed content. Failures are
  logged, with reasons only, to
  `~/.local/state/claude-openrouter/keyhelper.jsonl`. There is deliberately no
  1Password or `agent/run` path, and no key literal in the repo. Backlog:
  revisit key storage (Keychain or 1Password).
- **Worker deny rules**: no `gh pr merge`, default-branch pushes, `agent/run`,
  `esc`, `pulumi up`, `pulumi env open`, `op`, nor reads of `~/keys`. They are
  concatenated onto the exxo deny set; the allow set is exactly exxo's.
- **PreToolUse guard** `scripts/claude-openrouter-guard`: allows only fully
  resolved commands, blocks merges, default-branch pushes and workflow
  triggers, and logs to `guard.jsonl` (no command text).

`SETTINGS_MERGE` in `claude-sync` now also concatenates hook arrays per event
(shared hooks first, the overlay's after), so the guard adds to the shared
hooks instead of replacing them. Other contexts'
hooks are unchanged. `tests/claude-sync-openrouter.sh` covers all of this
against a throwaway repo copy and fake `$HOME`.

Known limits: deny rules are text-matched, so they can be dodged; the guard's
residual gaps are scripts, Makefiles and git hooks, scripts authored with the
Write tool, and obfuscated command names; behaviour under
`bypassPermissions` is unverified (smoke test). Job branches must avoid
"main" and "master" in their names or the push rules block them.

K3 facts (as of build): 1,048,576 context, $0.239 per M input, $10.80 per M
output; K3.1-pro is a later trial. Model ids carry no `[1m]` suffix yet
(ruling R-C7), and a smoke row tests that.

## Repo config: conventions skill, audit script, SessionStart hook

Three artefacts keep every repo's own Claude config in line with the global
layer (added 2026-10-23, after a survey found `just:*`/`git:*` local grants,
a blanket-trusted `agent/Justfile` with prod-mutating recipes, and 16 repos
restating global CLAUDE.md blocks):

- `files/claude/skills/claude-repo-config/` — the conventions (global vs
  committed vs local settings, deny floor, `agent/Justfile` read-only
  invariant and `ops.Justfile`, CLAUDE.md ≤300 lines with no restated
  globals) and the fix procedures. Shared to every context.
- `scripts/claude-config-audit` — stdlib Python check over one repo
  (`--repo`, default cwd) or the estate (`--estate`, roots default `~/dev`,
  skipping worktrees, `picnic` and repos idle >30 days unless `--all`);
  `--json`, `--explain`, `--fix-local` (writes `settings.local.json.bak`).
  It reads the allow set, floor and global headings from the fragments here,
  so it cannot disagree with what claude-sync deploys. Tests:
  `tests/test_claude_config_audit.py`.
- A `SessionStart` hook in `settings.shared.json` (matcher
  `startup|resume`, marker `# claude-config-audit`) runs it with `--quiet
  --hook` against `$CLAUDE_PROJECT_DIR`: silent when clean or not a git repo,
  otherwise a one-line `systemMessage` plus the findings as context. It
  always exits 0 and runs in ~0.1s. The hook references the script by its
  primary-checkout path (`$HOME/dev/dotfiles/scripts/…`), like the other
  dotfiles hooks, so it tracks `main`.

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

## MCP servers: merged into .claude.json, not copied

The third managed artefact, and the one that is not a `settings.json` key.
Claude Code keeps user-scope MCP servers in `<context>/.claude.json`, alongside
login state and per-project trust, so claude-sync MERGES
`files/claude/mcp.shared.json` (plus an optional `mcp.<account>.json`, same
account-wins precedence as the settings fragments) into that file's
`.mcpServers` rather than copying over it. Managed names win, hand-added
servers are preserved, and nothing else in `.claude.json` is disturbed. The
write is skipped when it would be a no-op, refuses to run if the file moved
between read and write, and swaps atomically in-directory — any live session
rewrites `.claude.json` continuously, and clobbering a token it has just
persisted is recoverable from nowhere.

Servers carrying a credential stay out of the repo: a JSON fragment has nowhere
to reference a 1Password item from, so a token-bearing server is added by hand
with `claude mcp add -s user` and merely preserved by the merge, never
codified. For the same reason both `claude-sync --diff` and the apply path
print server NAMES and never values — both land in terminals and transcripts
while the live file holds real tokens. Don't route around that by dumping
`.claude.json` to inspect a server.

**Procedure, same shape as settings and CLAUDE.md:** never hand-add a
credential-free server with `claude mcp add` and consider it done — it lands in
one context and the other two silently never get it. Put it in
`files/claude/mcp.shared.json` (or `mcp.<account>.json` when it genuinely
belongs to one account) and run `claude-sync`. Removal is deliberately NOT a
merge operation: deleting a server from the fragment only stops managing it, it
does not remove it from any context — retire one with `claude mcp remove -s
user <name>` under that CLAUDE_CONFIG_DIR.

The gap this closed (added 2026-08-23): every context had been populated by
hand, three times over, and `~/.claude-exxo-personal` was missed entirely — it
carried no MCP servers at all while `~/.claude-exxo` had four.

## Skills reach a context by exactly two paths

1. **Dotfiles skills** (`files/claude/skills/`, this skill included):
   personal gets a whole-directory symlink (`~/.claude-personal/skills` IS
   the repo dir — author a skill in place and it lands in git). exxo gets a
   REAL directory of per-skill symlinks curated by claude-sync against an
   allow list: only repo skills named in `shared_skills()` in
   `scripts/claude-sync` get linked in (currently `claude-workstation-setup`,
   `worktree-closedown`, `dotfiles-repo`, `claude-repo-config`, `squad-infra`, `squad-join`,
   `squad-orchestrator`, `squad-debug-review`, `reauth`). Every other repo skill is
   personal-only by default and must be explicitly promoted — add its name to
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

A repo skill on path 1 can itself be a byte-for-byte VENDORED copy of a public
upstream. `files/claude/skills/mantine-{form,combobox,custom-components}` are
`mantinedev/skills`, refreshed by `scripts/vendor-mantine` and pinned by commit
in `files/claude/vendor/mantine.lock.json` (`--check` reports whether the pin is
behind). Byte-identical is the point — no local edits, no spliced-in provenance
headers — so `git diff` after a refresh shows what Mantine changed and nothing
else; provenance lives in the lockfile and our own framing in the hand-written
`mantine-docs` skill beside them, which also routes between the three Mantine
lookup paths (MCP server, these skills, the `llms.txt` index). Never edit a
vendored directory: the next refresh destroys the edit and hides upstream's.

This adds no third delivery path, but it does mean one upstream can reach the
two contexts by DIFFERENT paths. The `mantine-*` skills are absent from
`shared_skills()`, so exxo receives the same content on path 2 instead, as the
`exxo-mantine@exxo-skills` plugin. That is the `run-with-secrets` rule
generalised — one capability, one delivery path per context, never two at once
— with a second reason on top: the personal context must never depend on a
private Exxo repo, so it vendors from upstream directly. Both repos pull from
`mantinedev/skills` and never from each other, so the copies cannot
chain-drift.

Not a delivery path you manage: Claude Code itself caches the claude.ai
ACCOUNT skills (`anthropic-skills:*` — docx, pdf, skill-creator, …) under
`<context>/skills/synced/` (manifest.json + a bucket dir; first seen
2026-09-27). It is per-account and self-refreshing. In personal it appears as
`files/claude/skills/synced/` via the whole-dir symlink and is gitignored;
claude-sync's curated path skips it (`is_cc_managed()`) instead of adopting it
into the repo. Never vendor, commit or hand-edit it — account skills are
managed on claude.ai.

## Subagent definitions: same two shapes as skills

Dedicated subagents live in `files/claude/agents/<name>.md` (frontmatter
`name`, `description`, `model`; body = the procedure, which restates the
environment mechanics a subagent doesn't inherit). Personal gets
`~/.claude-personal/agents` as a whole-directory symlink to that dir; exxo and
exxo-personal get a real `agents/` directory of per-file symlinks for the
names in `shared_agents()` in `scripts/claude-sync` (currently `implementer`,
`reviewer`, `git-pr-ops`, `investigator`, `sanity-cms`, `notion-ops` — all of
them). Same allow-list and adoption rules as skills: a new agent is
personal-only until named there, and a real file created in a curated
`agents/` dir is adopted into the repo on the next sync. Verified 2026-10-23
that Claude Code follows both a symlinked `agents/` dir and symlinked agent
files. `claude-sync --diff` reports each agent's link state.

The delegation policy in `CLAUDE.md.shared` routes to these first, with
`general-purpose` as the stated-reason fallback. Progress is measured with
`scripts/claude-usage-scan` against
`docs/superpowers/specs/2026-10-23-usage-baseline.json` (goal: general-purpose
under 25% of subagent tokens by 2026-11-22).

## Plugins kept off by default (lazy load)

`notion@claude-plugins-official` and `vercel@claude-plugins-official` are
`false` in `settings.shared.json`: their skills were unused, their listing cost
every turn. Enable one for a session with `/plugin` when a task needs it; the
next `claude-sync` turns it back off. Explicit `false`, not a deleted key — the
merged settings file replaces the live one, and an absent key leaves an
installed marketplace plugin on. Notion in exxo goes through the
`claude_ai_Notion` account connector via the `notion-ops` agent; the legacy
hand-added `notion` server is retired with `claude mcp remove -s user notion`
under each CLAUDE_CONFIG_DIR. `linear@claude-plugins-official` stays on because
parentedit's `linear-tpe` skill names `mcp__plugin_linear_linear__*` tools.
Figma reaches a context only inside the claude.ai account-synced `design`
plugin (`<context>/plugins/synced/`), which the fragments don't manage.

## What is deliberately NOT shared or synced

- **Permission approvals** — per repository, in `.claude/settings.local.json`
  at the repo root, untouched by claude-sync. (The audit's `--fix-local`
  prunes them on request; nothing does so automatically.)
- **Auto-memory** — per context, under `<context>/projects/<cwd-slug>/memory/`.
  Kept segregated on purpose (work/personal leakage); durable architecture
  facts belong here in this skill instead.
- **OpenRouter context state** — `~/.claude-exxo-openrouter` links only
  `plugins` to `~/.claude-exxo`. Its `projects/`, `history.jsonl`, `plans`,
  `tasks` and `todos` are its own, and there is no cross-provider resume:
  transcripts carry provider-specific thinking blocks, so a session started on
  Anthropic cannot be continued on OpenRouter or vice versa.
- **Login state** (`.claude.json`), sessions, history — per context. The one
  exception is that file's `.mcpServers` key, which claude-sync merges into
  (above); every other key in `.claude.json` is left exactly as Claude Code
  wrote it.

## Quick diagnosis

- Session sees Exxo skills in personal (or vice versa) → wrong
  CLAUDE_CONFIG_DIR. Concrete check: `echo $CLAUDE_CONFIG_DIR` —
  `/Users/tim/.claude-personal` for bare `claude`, `/Users/tim/.claude-exxo`
  for `claude-exxo`, `/Users/tim/.claude-exxo-personal` for
  `claude-exxo-personal`, `/Users/tim/.claude-exxo-openrouter` for the
  OpenRouter worker context; empty means the legacy default context (fine if
  launched deliberately via `claude-default` or an unpinned tool, wrong if
  an account wrapper was intended).
- A settings or CLAUDE.md change vanished → it was hand-written into a
  context file; promote it into the matching fragment (`settings.<account>.json`
  or `CLAUDE.md.shared`/`CLAUDE.md.<account>`) and re-run `claude-sync`.
- An MCP server is missing in one context but present in another → check
  whether it's managed. Credential-free servers belong in
  `files/claude/mcp.shared.json` (this now includes `Sanity`, OAuth-only
  since 2026-09-28 and no longer token-bearing) and reach every context on
  the next `claude-sync`; genuinely token-bearing ones (`notion`) are
  hand-added per context by design and simply haven't been added there yet —
  `claude mcp add -s user` under that CLAUDE_CONFIG_DIR. `claude-sync --diff`
  lists the managed names per context, and the unmanaged ones it is leaving
  alone, without printing any values.
- `sanity mcp configure` (Sanity CLI v8.x) hard-codes `~/.claude.json` and
  ignores `CLAUDE_CONFIG_DIR`, so it only ever reaches the legacy default
  context, never a real one — don't use it; add/change the server via the
  `mcp.shared.json` fragment instead.
- Targeting another context inline (`CLAUDE_CONFIG_DIR=~/.claude-exxo claude
  mcp ...`) has no effect for bare `claude` — the shell wrapper pins
  `CLAUDE_CONFIG_DIR` to personal and overrides the inline value. Use `env
  CLAUDE_CONFIG_DIR=<ctx> claude ...` or `command claude` instead.
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
mechanism between them; repo-managed MCP servers and the vendored Mantine
materials added 2026-08-23. Deferred follow-ups tracked in
`files/claude/README.md`.
