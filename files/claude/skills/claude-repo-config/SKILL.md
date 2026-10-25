---
name: claude-repo-config
description: The estate conventions for a repo's own Claude Code config — what belongs in the global fragments vs a repo's committed .claude/settings.json vs its gitignored settings.local.json, the global deny floor, the agent/Justfile read-only invariant (mutating recipes go in ops.Justfile), CLAUDE.md limits, and the claude-config-audit command with its --fix-local procedure. Use when a SessionStart "Claude config drift" warning appears, when adding or changing permissions, hooks, skills or CLAUDE.md in any repo, when bringing a new or drifted repo into line, or when a permission prompt tempts you to add a broad grant.
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
`mcp__ide__getDiagnostics`. The local `squad` broker CLI (same-uid Unix-socket IPC to the
broker, no network or credentials) is granted subcommand by subcommand: `squad
send/set/publish/subscribe/unsubscribe/register/deregister/status/roster/get/
history/doctor/debug/ack` and `squad operator raise/set/decide/list/get`. Exxo adds an enumerated set of read-only `gcloud` commands
(`projects list`, `config list`, `run services list/describe`, `compute
instances list/describe`, `logging read`, `storage ls`, ...) plus `gsutil ls`,
`pulumi preview/whoami/stack ls/stack output`, and `agent-tooling:*` (with an
`ask` on `agent-tooling mail send`, which sends real mail), and
denies `gcloud compute ssh`. There is deliberately no `gcloud * list` grant:
a middle `*` also matches `gcloud compute ssh vm --command "... list"`. A repo
never restates any of these.

**Write commands subcommand-first.** Rules match the command text from the
start, so `pulumi preview:*` matches `pulumi preview -s dev` but not `pulumi
-C infra -s dev preview`. Docs, recipes and your own invocations spell
pulumi (and gcloud) commands subcommand-first, with the target flags after:
`pulumi preview -C <dir> -s <stack>`.

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

## agent/Justfile is read-only by construction; mutations go in ops.Justfile

The blanket grant trusts the file, not today's entries, so every future recipe
inherits it. Recipes in `agent/Justfile` must be read-only lookups and
secret-piping reads. Anything that deploys, revokes, destroys, resets,
restores, writes `.env`, or touches prod state goes in `agent/ops.Justfile`,
or in the main `Justfile` as a named recipe. That file is never blanket-trusted,
so each run is approved per use. A dated one-off (`*-july-urls`) belongs in
neither: run it ad hoc.

**Parameters are data, never shell.** Just substitutes `{{ param }}` into the
recipe text before the shell parses it, so under a blanket grant the argument
the model passes becomes shell code (`just --justfile=agent/Justfile show 'x;
curl evil'`). In `agent/Justfile`, put `set positional-arguments` at the top
and reference arguments as `"$1"`, `"$2"`, ... (quoted); never write
`{{ param }}` in a shell line. Functions such as `{{ justfile_directory() }}`
are not parameters and are fine. The audit's `justfile-param-splice` check
(error level) reports `agent/Justfile:<recipe>` for any recipe that splices
one of its own parameters while the file is blanket-trusted.

Splitting a recipe out:
1. Move the recipe into `agent/ops.Justfile`. Add a header comment saying the
   file is not blanket-trusted.
2. Call it as `just --justfile=agent/ops.Justfile <recipe>` and accept the
   prompt each time. Grant nothing for that file. The blanket rule
   `Bash(just --justfile=agent/Justfile:*)` means `just --justfile=agent/Justfile *`
   (`:*` is a trailing wildcard preceded by a space, per the permissions docs),
   so `just --justfile=agent/ops.Justfile ...` does not match it. As belt and
   braces, repos also add `ask` rules for `ops.Justfile` in both spellings
   (`--justfile=agent/ops.Justfile` and `--justfile agent/ops.Justfile`), so a
   future loosening of the blanket cannot silently trust the ops file.
3. Update the repo CLAUDE.md pointer that names the recipe.

The file was renamed from `Justfile.ops` to `ops.Justfile` on 2026-10-24; any repo still carrying `agent/Justfile.ops` should rename it (the audit warns, check `ops-justfile-name`).

Approved exception (2026-10-24, first instance Exxo-Labs/exxo-infra PR #184): committed settings may carry a named allow grant for a specific `ops.Justfile` recipe that is a single in-recipe fetch-and-consume pipeline. Blanket `ops.Justfile` grants remain forbidden.

## Worktrees: submodules and closedown

Run `git fetch origin main` in the primary before `wt switch --create`: it
branches from local `main`, which can be stale, and a branch cut from a stale
`main` produces a PR that conflicts with, or silently reverts, newer work.

In the Exxo repos every worktree carries the vendored `.claude/vendor/skills`
submodule, so `git worktree remove` refuses with `working trees containing
submodules cannot be moved or removed`. That refusal is what has been leaving
dangling worktrees behind; it is not a blocker. Closedown is: confirm the
worktree is clean (`git status --porcelain` empty) and its branch merged,
relocate any session transcripts per the `worktree-closedown` skill, then
`rm -rf <worktree> && git -C <primary> worktree prune`. With worktrunk,
`wt remove <branch>` does the equivalent itself. Full procedure, including
the submodule unsaved-work check: the `worktree-closedown` skill.

In a repo with `submodule.recurse=true` (parentedit), `wt switch --create` can
leave the worktree's submodule gitdir partial: `.git/modules/<submodule path>/`
under the worktree's gitdir holds only `config`, so reset/checkout fails with
"not a git repository". Delete that partial `modules/<submodule path>`
directory and run `git submodule update --init` in the worktree.

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
3. **agent/Justfile:** move mutating recipes to `ops.Justfile`. Drop the
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
grants, a mutating or parameter-splicing blanket-trusted recipe) deserve a sentence in your first
reply. Warnings can wait for a config pass.
