# Claude Code config

The baseline used to be a single `settings.json`. It's now split into
fragments that `scripts/claude-sync` deep-merges with jq (`.[0] * .[1]`,
account wins, nested objects merge key-wise) and writes to
`~/.claude-<account>/settings.json` — still **copied, not symlinked**:
symlinking made the live user file *be* the repo file, and Claude Code writes
to that file, so the repo was perpetually dirty.

- `settings.shared.json` — the baseline applied to every context.
- `settings.personal.json` — the personal-context fragment, currently `{}`.
- `settings.exxo.json` — Exxo-only: enables the `exxo-common@exxo-skills`
  plugin and registers the `exxo-skills` marketplace under
  `extraKnownMarketplaces`.

The split exists because the Exxo context must receive the Exxo skills
marketplace/plugin while `~/.claude-personal` must never get it (homelab #76,
Linear ENG-20).

`CLAUDE.md` follows the same shape, one level simpler: `claude-sync`
concatenates `CLAUDE.md.shared` with an optional `CLAUDE.md.<account>`
fragment (plain text, not a jq merge) and copies the result into each
context's `CLAUDE.md` — copied, not symlinked, for the same reason as
settings.json: the file can be hand-edited in a context (or edited by a
Claude session), and a symlink would let that edit land in the repo silently
instead of surfacing as drift to promote deliberately. Unlike the settings
fragments, the account fragment is optional — `CLAUDE.md.personal` and
`CLAUDE.md.exxo` don't need to exist until an account actually needs
instructions the other shouldn't get; `CLAUDE.md.shared` alone is a valid
baseline. This closes a gap where both contexts had independently
hand-duplicated copies of the same global instructions with no sync
mechanism at all (found and fixed 2026-08-18).

MCP servers are the same shared+fragment family, but they are the one piece of
repo-managed config that is not a `settings.json` key at all: Claude Code keeps
user-scope servers in `<context>/.claude.json`, alongside login state and
per-project trust. So `mcp.shared.json` — plus an optional `mcp.<account>.json`,
same precedence as the settings fragments, account wins per server name — is
**merged** into that file's `.mcpServers` rather than copied over it. Managed
names win, hand-added servers are left untouched, and nothing else in
`.claude.json` is disturbed. That is what makes a server like `mantine` present
in every context by construction instead of by remembering to run `claude mcp
add` three times, which is exactly how the gap that motivated this arose:
`~/.claude-exxo-personal` had no MCP servers at all while `~/.claude-exxo`
carried four (added 2026-08-23).

Four properties of the merge, all deliberate:

- Credential-bearing servers stay **out** of the repo. Secrets are referenced,
  never written, and a JSON fragment has nowhere to reference a 1Password item
  from — so a token-bearing server (`notion`, `Sanity`) is added by hand with
  `claude mcp add -s user` and merely preserved by the merge, never codified.
- Both `--diff` and the apply path print server **names only, never values**.
  Both land in terminals and transcripts, and the live file holds real tokens.
- The write is skipped when it would be a no-op, refuses to run if the file's
  checksum moved between read and write, and swaps atomically in-directory. Any
  live session rewrites `.claude.json` continuously, and clobbering a token it
  has just persisted is recoverable from nowhere.
- Removal is not a merge operation. Dropping a server from the fragment stops
  managing it; it does not delete it from a context. Retire one with
  `claude mcp remove -s user <name>` under that `CLAUDE_CONFIG_DIR`.

Skills follow the same split. `~/.claude-personal/skills` stays a
whole-directory symlink to `files/claude/skills`. `~/.claude-exxo/skills` is
a real directory of per-skill symlinks maintained by `claude-sync`, built
from an allow list: a `shared_skills()` list in `scripts/claude-sync` names
the repo skills that are cross-account — currently `claude-workstation-setup`,
`worktree-closedown` and `dotfiles-repo` — and only those are linked into exxo;
every other repo skill is personal-only by default. The allow-list replaced an
earlier exclusion list after `run-with-secrets` — homelab guidance (op-shim,
Ansible, zima/ragnar) — turned up alongside the `exxo-common` plugin's own
`run-with-secrets` (`agent/run` + `agent.env`) in the exxo context; both were
visible at once (verified 2026-08-18), which risked an Exxo session following
homelab credential guidance. In the Exxo context, the plugin's
`exxo-common:run-with-secrets` is the only one. To make a repo skill
cross-account, add its name to `shared_skills()`.

Contexts are created by `scripts/claude-contexts`; the `claude`,
`claude-personal`, `claude-exxo` and `claude-exxo-personal` shell wrappers
select them via `CLAUDE_CONFIG_DIR` (see `src/.config/fish/common.fish`,
`src/.zshrc`).

## Vendored upstream skills: Mantine

Mantine is the standard UI framework for Exxo frontends and for personal
projects, and it moves fast enough that answering from memory is simply wrong.
Upstream publishes three agent-facing things
([mantine.dev/guides/llms](https://mantine.dev/guides/llms/)): an MCP server, a
skills repo, and `llms.txt`/`llms-full.txt`. The server is registered for every
context through `mcp.shared.json` above. `scripts/vendor-mantine` handles the
other two — it vendors `mantinedev/skills` (public, pinned by commit in
`vendor/mantine.lock.json`) into
`skills/mantine-{form,combobox,custom-components}`, and fetches the compact
`llms.txt` index into `skills/mantine-docs/references/`. `--check` reports
whether the pin is behind upstream and lists what has landed since.
`llms-full.txt` (~1.8MB, rewritten every release) is deliberately not vendored:
it would put a megabyte of churn in git to duplicate what the MCP server
already answers on demand.

The vendored directories are kept **byte-identical** to upstream — no local
edits, no provenance headers spliced in. That is the whole point: `git diff`
after a refresh shows exactly what Mantine changed and nothing else. Provenance
lives beside them in the lockfile, and our own framing lives in
`skills/mantine-docs/SKILL.md`, which is ours and not vendored — it routes
between the three lookup paths and says which to reach for first.

The `mantine-*` skills are deliberately **not** in `shared_skills()`, so they
stay personal-only. The exxo context receives the same upstream by the plugin
path instead, as `exxo-mantine@exxo-skills` from `Exxo-Labs/skills`. That is
the `run-with-secrets` rule again — one capability, one delivery path per
context, never two at once — but the stronger reason here is that the personal
context must never depend on a private Exxo repo, so it vendors from
`mantinedev/skills` directly. Both repos pull from upstream and never from each
other, so the two copies cannot chain-drift: they are either at the same
upstream commit or visibly not.

## The exxo-personal overlay context

`~/.claude-exxo-personal` (wrapper `claude-exxo-personal`, desktop
`claude-d-exxo-personal`) is the exxo context with only the login swapped to
the personal subscription — for when exxo quota is maxed out. It works
because auth is naturally the only per-dir state: credentials live in the
keychain keyed by a hash of `CLAUDE_CONFIG_DIR`, and `.claude.json`
(login/onboarding/per-project trust) is private to the dir. `claude-sync`
builds its `settings.json`/`CLAUDE.md`/skills from the **exxo** fragments
(the `CONTEXTS` mapping) and symlinks its durable state — `projects/`
(transcripts + auto-memory), `history.jsonl`, `plugins/`, `file-history`,
`plans`, `tasks`, `todos`, `paste-cache` — into `~/.claude-exxo`, so
`claude-exxo-personal --resume` continues the very session that ran out of
quota. First use needs a one-time `/login` with the personal account (and
one-time per-repo trust prompts).

Known limits: claude.ai-side features (MCP connectors, cloud sessions,
artifacts, ultrareview billing) follow the logged-in account, not the config
dir — Exxo-org-scoped connectors aren't reachable under the personal login,
so connector-heavy sessions belong on real exxo quota. Desktop session
pickers are per user-data dir; resume across the two profiles via the CLI.

## Changing model / effort — use the flags, not the slash commands

The baseline pins `model: fable` and `effortLevel: medium` — the orchestrator tier; subagents get cheaper models per the CLAUDE.md.shared orchestrator/subagent policy. Both are *defaults
read at session start*, and there are two ways to change them for a session —
only one of which leaves the file alone:

| Do this | Effect |
|---|---|
| `claude --model fable --effort medium` | session only, **file untouched** |
| `/model` picker → `s` | session only, **file untouched** |
| `/model fable` typed directly | **writes** `model` as your new default |
| `/model` picker → `Enter` | **writes** `model` as your new default |
| `/effort medium` in an interactive session | **writes** `effortLevel` |

So: **prefer the launch flags, or `s` in the picker.** Nothing enforces this —
deliberately. If a default does get rewritten it shows up as a diff on this
file the next time you look, and is reverted like any other unwanted change.

Two caveats from the [docs](https://code.claude.com/docs/en/model-config):

- First run of Fable 5 / Opus 4.8 / 4.7 applies *that model's* default effort
  and holds it across sessions until you set one explicitly, which can override
  the pin. A non-interactive `/effort` can't release the hold — pass `--effort`
  at launch.
- `max` and `ultracode` cannot be persisted here at all; `effortLevel` doesn't
  accept `ultracode`, and `max` is session-only unless set through
  `CLAUDE_CODE_EFFORT_LEVEL`.

## What is NOT in this file

Permission approvals ("yes, don't ask again") are **per repository**, not
per account: Claude Code writes them to `.claude/settings.local.json` at the
git repository root. Outside a repository it writes them in the directory the
session started from. Nothing here touches them.

## Deferred follow-ups

- `~/.claude-exxo-personal` still has no MCP servers of its own beyond what
  `claude-sync` manages. `~/.claude-exxo` carries four hand-added ones —
  `Sanity`, `notion`, `playwright`, `workos` — and `~/.claude-personal` three of
  them (no `workos`). They hold live credentials, so they cannot be codified
  into `mcp.shared.json`; re-adding them by hand with `claude mcp add -s user`
  under `CLAUDE_CONFIG_DIR=~/.claude-exxo-personal` is outstanding
  (noted 2026-08-23).
- The `notion` and `Sanity` entries hold plaintext bearer tokens in each
  context's `.claude.json` (`env.NOTION_TOKEN` and an `Authorization` header
  respectively). Nothing here can fix that — a user-scope MCP server has no
  reference-at-invocation form, which is precisely why those two are hand-added
  rather than codified, and the file never enters a repo. But it is host state
  outside this repo's reach and a standing exposure worth recording rather than
  rediscovering: anything that can read `$HOME` can read the tokens, and
  rotation is the only mitigation available (noted 2026-08-23).

(Resolved 2026-08-18: [Exxo-Labs/skills#4](https://github.com/Exxo-Labs/skills/pull/4)
merged — the plugin's `purge-esc-cache` is now `purge-secret-cache`, plugin
updated to the post-merge snapshot and re-checked; nothing here referenced
the old name.)

(Resolved 2026-08-18: the `exxo-skills` marketplace was repointed from the
local checkout to `git@github.com:Exxo-Labs/skills.git` after
[Exxo-Labs/skills#2](https://github.com/Exxo-Labs/skills/pull/2) merged —
SSH, not HTTPS, because Claude Code's background plugin refresh disables git
credential helpers and HTTPS fails on private repos. Changing a marketplace's
source in `settings.exxo.json` is not enough for an already-registered
context: `claude plugin marketplace remove exxo-skills` + `add <git-url>` +
`claude plugin install exxo-common@exxo-skills` under the exxo
CLAUDE_CONFIG_DIR re-registers it.)
