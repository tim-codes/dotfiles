# Claude Code config

`settings.json` here is the baseline for every per-account context
(`~/.claude-personal`, `~/.claude-exxo`). It is applied by `scripts/claude-sync`
and **copied, not symlinked** — symlinking made the live user file *be* the repo
file, and Claude Code writes to that file, so the repo was perpetually dirty.

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
