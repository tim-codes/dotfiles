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

Skills follow the same split. `~/.claude-personal/skills` stays a
whole-directory symlink to `files/claude/skills`. `~/.claude-exxo/skills` is
a real directory of per-skill symlinks maintained by `claude-sync`, built
from an allow list: a `shared_skills()` list in `scripts/claude-sync` names
the repo skills that are cross-account — currently just
`claude-workstation-setup` — and only those are linked into exxo; every
other repo skill is personal-only by default. The allow-list replaced an
earlier exclusion list after `run-with-secrets` — homelab guidance (op-shim,
Ansible, zima/ragnar) — turned up alongside the `exxo-common` plugin's own
`run-with-secrets` (`agent/run` + `agent.env`) in the exxo context; both were
visible at once (verified 2026-08-18), which risked an Exxo session following
homelab credential guidance. In the Exxo context, the plugin's
`exxo-common:run-with-secrets` is the only one. To make a repo skill
cross-account, add its name to `shared_skills()`.

Contexts are created by `scripts/claude-contexts`; the `claude`,
`claude-personal` and `claude-exxo` shell wrappers select them via
`CLAUDE_CONFIG_DIR` (see `src/.config/fish/common.fish`, `src/.zshrc`).

## Changing model / effort — use the flags, not the slash commands

The baseline pins `model: sonnet` and `effortLevel: high`. Both are *defaults
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

- The plugin currently exposes `purge-esc-cache`;
  [Exxo-Labs/skills#4](https://github.com/Exxo-Labs/skills/pull/4) renames it
  `purge-secret-cache`. Re-check references after it merges.

(Resolved 2026-08-18: the `exxo-skills` marketplace was repointed from the
local checkout to `git@github.com:Exxo-Labs/skills.git` after
[Exxo-Labs/skills#2](https://github.com/Exxo-Labs/skills/pull/2) merged —
SSH, not HTTPS, because Claude Code's background plugin refresh disables git
credential helpers and HTTPS fails on private repos. Changing a marketplace's
source in `settings.exxo.json` is not enough for an already-registered
context: `claude plugin marketplace remove exxo-skills` + `add <git-url>` +
`claude plugin install exxo-common@exxo-skills` under the exxo
CLAUDE_CONFIG_DIR re-registers it.)
