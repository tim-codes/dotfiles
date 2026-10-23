---
name: claude-repo-config
description: The estate conventions for a repo's own Claude Code config — what belongs in the global fragments vs a repo's committed .claude/settings.json vs its gitignored settings.local.json, the global deny floor, the agent/Justfile read-only invariant (mutating recipes go in Justfile.ops), CLAUDE.md limits, and the claude-config-audit command with its --fix-local procedure. Use when a SessionStart "Claude config drift" warning appears, when adding or changing permissions, hooks, skills or CLAUDE.md in any repo, when bringing a new or drifted repo into line, or when a permission prompt tempts you to add a broad grant.
---

# Repo-level Claude config: the estate conventions

You may have landed in any repo. These conventions hold in all of them. The
check is `~/dev/dotfiles/scripts/claude-config-audit`. The global fragments it
compares against live in `~/dev/dotfiles/files/claude/` and reach every context
through `claude-sync` (see the `claude-workstation-setup` skill).

## Three layers, and what goes in each

| Layer | File | Holds |
|---|---|---|
| Global | dotfiles `settings.shared.json` (every context), `settings.exxo.json` (Exxo only) | the read-only allow set, the deny floor, hooks, plugins |
| Repo, committed | `<repo>/.claude/settings.json` | only what is specific to this repo (see below) |
| Repo, local | `<repo>/.claude/settings.local.json` (gitignored) | almost nothing |

**Global read-only allow set.** `git status/diff/log/branch/show/worktree
list`, `gh pr view/list/checks/diff`, `gh run view/list`, `just --list`,
`WebSearch`, `WebFetch` for github.com and raw.githubusercontent.com, and
`mcp__ide__getDiagnostics`. Exxo adds `gcloud * list/describe`, `pulumi
preview/whoami/stack ls/stack output`, and `agent-tooling:*`. A repo never
restates any of these.

**Committed `.claude/settings.json`** holds only these:
1. Named recipe grants, one per recipe: `Bash(just check:*)`,
   `Bash(just test-web:*)`. Never `Bash(just:*)`, which approves every recipe,
   deploys and restores included.
2. The `agent/Justfile` blanket (`Bash(just --justfile=agent/Justfile:*)`),
   and only while every recipe in that file is read-only (below).
3. Hooks, such as the Exxo `just skills-check` SessionStart hook.
4. Denies specific to this repo, beyond the floor.
5. Tool grants specific to this repo that have no global equivalent, such as
   `Bash(pnpm test:*)`. Use one spelling per intent, in the `Bash(cmd sub:*)`
   form.

**`settings.local.json`** is per machine and never reaches a worktree.
`worktree-copy-local-env` doesn't copy `.claude/`, so nothing load-bearing can
live there. Benign repo-local items are fine: `additionalDirectories`, a few
docs domains, a named recipe you are still trialling. Claude Code writes your
"don't ask again" answers here, and that is how drift accumulates.

**Never grant**, in either repo file:
- `just:*` or `git:*`
- interpreters and launchers: `node:*`, `python:*`, `python3:*`, `npx:*`,
  `pnpm:*`, `bash:*`, `curl:*`, `gh:*`
- `rm:*`, `ssh:*`, `ansible*`, `docker rm/run`, `git reset/rebase`
- `pulumi up/refresh/import/destroy`
- anything that reveals a secret: `esc env get`, `gcloud secrets versions
  access`, `--reveal`, `--show-secrets`
- a command with a secret resolved inline, like `X_PWD=$(gcloud secrets …)`

Each of these is effectively arbitrary execution or mutation. In auto mode
the classifier is the backstop, but a grant skips it.

## The deny floor, and why it is global

`settings.shared.json` denies `op read`, `--reveal`, `--show-secrets`, `pulumi
env open`, `esc env open` and `gcloud secrets versions access`. Each comes in
two forms, plain and `* <cmd>`, so the deny also matches when the command is a
later segment. The floor also denies `Read` on `.claude.json` and
`.credentials.json`.

Claude Code evaluates deny rules before allow rules, across every scope. A
deny matches any subcommand, including `$(…)` and loop bodies, and skips
leading env assignments. So a user-level deny can't be loosened from a repo
file. The floor protects every repo, including ones with no settings at all,
and the wildcard forms close the flag-order bypass that the old prefix rules
had (`pulumi env get x --show-secrets`).

A repo that ships its own copy of the floor must carry the whole floor, in
these exact spellings. Exxo repos do this for colleagues' machines that don't
have these dotfiles. The audit flags a partial copy. A deny list of
repo-specific entries only is fine.

**Consequence for you:** any Bash command whose text contains `--reveal`,
`--show-secrets` or ` op read` is denied, even a `grep` for those strings. Use
the Grep tool, or write such text with Write or Edit, not through a shell.
When a recurring task needs a secret, don't ask for the deny to be lifted. Add
a secret-piping recipe that fetches and consumes the secret in one in-recipe
pipeline and prints nothing.

## agent/Justfile is read-only by construction; mutations go in Justfile.ops

The blanket grant trusts the file, not today's entries, so every future recipe
inherits it. Recipes in `agent/Justfile` must be read-only lookups and
secret-piping reads. Anything that deploys, revokes, destroys, resets,
restores, writes `.env`, or touches prod state goes in `agent/Justfile.ops`,
or in the main `Justfile` as a named recipe. That file is never blanket-trusted,
so each run is approved per use. A dated one-off (`*-july-urls`) belongs in
neither: run it ad hoc.

Splitting a recipe out:
1. Move the recipe into `agent/Justfile.ops`. Add a header comment saying the
   file is not blanket-trusted.
2. Call it as `just --justfile=agent/Justfile.ops <recipe>` and accept the
   prompt each time. Grant nothing for that file.
3. Update the repo CLAUDE.md pointer that names the recipe.

## CLAUDE.md: at most 300 lines, no restated globals

A repo CLAUDE.md is loaded on every turn, on top of roughly 430 lines of global instructions.
Keep only what a session in this repo needs every turn: what the repo is,
layout, commands and recipes, repo-specific rules.
- **Restate nothing global.** This covers credentials through `agent/run`,
  secrets referenced not written, blanket-trusted files, British English,
  commit/push cadence, branch and worktree rules, and the subagent policy.
  Where a reminder helps, use one pointer line: `Credentials: global rules +
  the exxo-common run-with-secrets skill apply.`
- **Over 300 lines** (counting `@imports`): move changelogs, design notes and
  reference material into `docs/`, as dated files plus a short index, or into
  an existing skill, and leave a pointer behind. Cut and relocate the text;
  don't rewrite its voice.
- **Repo agents**: phrase a directive as "project agent `ui` takes precedence
  over the global `implementer` for UI work". Project agents in
  `.claude/agents/` win over the global ones for the work they name.

## The audit

```
~/dev/dotfiles/scripts/claude-config-audit                    # this repo (cwd)
~/dev/dotfiles/scripts/claude-config-audit --repo <path>
~/dev/dotfiles/scripts/claude-config-audit --estate [--root DIR] [--all]
    --json | --quiet | --explain (dry run of --fix-local) | --fix-local
```

It exits 1 on any error-level finding. Estate mode skips linked worktrees,
anything with `picnic` in the path, and repos idle for more than 30 days
unless you pass `--all`. It never fetches, so the submodule distance is
measured against the local `origin/main`.

**`--fix-local` procedure** (the local file is gitignored, so you edit it in
the primary checkout):
1. Run `claude-config-audit --explain` and read each entry it would remove.
2. Run `claude-config-audit --fix-local`. It writes `settings.local.json.bak`
   next to the file, then removes:
   - dangerous grants
   - entries the global or committed set already covers
   - shell fragments, heredoc commit messages and one-off absolute paths
   - dead plugin grants (`mcp__plugin_Notion_notion__*`, `mcp__plugin_vercel_*`)
   - bulk research-domain lists (more than 10 non-docs domains)

   It keeps `deny`, `additionalDirectories` and other keys. An emptied file
   becomes `{}`.
3. Validate the result with `jq . .claude/settings.local.json`.
4. If a removed grant was genuinely needed, put it back as a narrow,
   repo-specific entry, or as a named recipe in the committed file.

## Bringing a new or drifted repo into line

1. Run `claude-config-audit`, and note the errors first.
2. **Committed settings:** delete what the global set covers. Replace
   `just:*` with named recipe grants. Normalise spellings. Keep hooks intact.
   Validate with `jq .`.
3. **agent/Justfile:** move mutating recipes to `Justfile.ops`. Drop the
   blanket grant if the file can't be made read-only.
4. **Local file:** follow the `--fix-local` procedure above.
5. **CLAUDE.md:** replace restated globals with pointers, and relocate
   reference material until the file is under 300 lines. Fix stale paths.
6. **Skills:** run `just skills-update` (Exxo), or `git submodule update
   --remote .claude/vendor/skills`. Use upstream names for skill links. Delete
   a link the context already delivers: `mantine-*` via the exxo-mantine
   plugin, or any user-level skill.
7. Re-run the audit until it's clean. Then branch, open a PR, and merge per
   the global git rules. Production Exxo repos keep their human-review gate.

## The SessionStart warning

Every session runs `claude-config-audit --repo "$CLAUDE_PROJECT_DIR" --quiet
--hook` at startup and resume. It is silent when the repo is clean or isn't a
git repo. When it finds something, you see a one-line "Claude config drift in
<repo>" message, and the findings land in context.

The warning reports drift; it doesn't ask you to fix anything. Mention it to
the operator. Fix it only if they ask, or if the task already touches repo
config. Never fix it by weakening the audit or the floor. Errors (dangerous
grants, a mutating blanket-trusted recipe) deserve a sentence in your first
reply. Warnings can wait for a config pass.
