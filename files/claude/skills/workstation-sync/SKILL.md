---
name: workstation-sync
description: Bring this MacBook's whole dev stack (dotfiles, homelab, exxo skills, agent-tooling, tmux-home, stray, the upstream tools in the manifests, plus Claude plugins in every context) fully up to date — survey, branch/push local work, merge Tim-approved PRs, pull, reinstall what changed. The heavy update, interactive, machine-agnostic. For a quick start-of-day readiness check use workstation-setup instead; for how the Claude setup works use claude-workstation-setup. Use when Tim says "sync my dev stack", "update everything", "bring this machine up to date", "/workstation-sync".
---

# Workstation sync: bring the dev stack up to date

Dev stack = primary checkouts of `~/dev/dotfiles`, `~/dev/homelab`,
`~/dev/exxo/skills`, `~/dev/exxo/agent-tooling` (setup repos), `~/dev/tmux-home` and
`~/dev/oss/stray` (authored open-source, tim-codes, public), plus Claude plugins per
context. Incorporated upstream tools with no checkout, althemer (fork of xdagiz/althemer)
and worktrunk, are refreshed only through the dotfiles manifests (cargo-update,
brew-update, plugin refresh); odin-awake is a Windows tool and out of scope. This list is
the canonical inventory of the stack. squad (~/dev/squad) is deliberately excluded while under active development; it is managed by its own sessions. Re-add it to this list to include it.
Tim is present. Runs on either MacBook, so use `~`-relative paths, never a hostname.

## Output rule (governs the whole run)

Run silently. No per-step narration, no intermediate tables. Speak mid-run only for:
(a) errors and failures; (b) decisions Tim must make (PRs to merge, stash vs
branch, a checkout not on main, an ff-only failure); (c) a heads-up just
before a prompt he must answer (Touch ID, browser OAuth, sudo/GUI). Delegate
noisy steps (installs, plugin sweeps, the survey) to a subagent so only its
conclusion reaches you. Finish with ONE concise checklist (step g).

## Rules a fresh session lacks

- SSH remotes only (`git@host:...`); an HTTPS remote is a defect, repoint it.
- End commits with the attribution trailer from the session's own rules.
- Never print secrets or run `op read`/`--reveal`; credentials go through `agent/run` in Exxo repos.
- A command that looks hung is probably waiting on Touch ID or another prompt: say so and wait, never kill or retry.
- The repo's own runner (`just`, `scripts/`) beats the raw tool. Explicit targets: `git -C <dir>`, `gh -R <owner/repo>`.
- Never touch another session's worktree. Never commit to main.

## a. Survey (silent)

Per repo (`dotfiles`, `homelab`, `tmux-home`, `stray` are tim-codes; `exxo/skills` and
`exxo/agent-tooling` are Exxo-Labs), with `git -C <dir> fetch --prune`, collect: current branch
(should be main), dirty tree (`status --porcelain`), unpushed commits
(`log @{u}..`), ahead/behind `origin/main`, and `git worktree list` (plus `wt list` where
worktrunk is used) noting worktrees with uncommitted or unpushed work. Report other
worktrees only in the final summary; never act on them. Show survey results only
where a decision is needed.

## b. Local changes

- A primary checkout not on main: stop and ask Tim.
- Uncommitted work in a primary checkout: move it onto a new branch, commit in logical
  chunks, push, open a draft PR (`gh pr create --draft -R <repo>`). Ask Tim whether it is
  work to keep (branch) or throwaway/WIP (stash); stash only on his confirmation.
- Dotfiles: use a worktree (`wt switch --create <branch>`), never switch branches in
  `~/dev/dotfiles` (live-symlinked config; see the `dotfiles-repo` skill). Remove finished
  worktrees only via `worktree-closedown`.
- Unpushed commits on a branch: push, and open a draft PR if none exists.
- Production-stage Exxo repos need human review before merge; Exxo-Labs repos are org
  repos, so their merges are Tim's call.

## c. Merges

`gh pr list -R <repo> --author @me --json number,title,isDraft,mergeable,statusCheckRollup,url`
for each of the six repos. Ask Tim which, if any, to merge (draft/ready, CI, mergeable).
Merge nothing without his explicit per-PR approval; squash-merge approved ones
(`gh pr merge -R <repo> <n> --squash`).

## d. Pull

Record `old=$(git -C <dir> rev-parse HEAD)`, then `git -C <dir> pull --ff-only` on main
in every primary checkout. If ff-only fails, stop and report; never rebase or reset.

## e. Post-pull actions

Driven by `git -C <dir> diff --name-only old..new`.

- **dotfiles**
  - anything under `src/` changed: `stow --target ~ src` run from `~/dev/dotfiles` (the
    fish `restow` function does not exist in zsh);
  - `scripts/claude-contexts` changed: run it;
  - ALWAYS `~/dev/dotfiles/scripts/claude-sync` from the primary checkout, then
    `scripts/claude-sync --diff` must be clean (backups to inspect are described in
    `claude-workstation-setup`);
  - dependency manifests: run only the script whose manifest changed — `scripts/brew-update`
    (brewDeps/brewCasks), `scripts/cargo-update`, `scripts/pnpm-globals`,
    `scripts/pipx-packages`, `scripts/gcloud-setup`, `scripts/pwsh-modules`,
    `scripts/tmux-plugins` — or offer full `src/bin/deps-up` if several changed or Tim asks.
    Always prefix `cargo-update` and `deps-up` with `CARGO_UPDATE_SKIP=tim-codes/squad`. squad
    stays in the manifest for fresh machines but is excluded from this sync.
    Warn Tim before anything that may raise a sudo or GUI prompt (brew casks) and run it
    on its own, not in a compound command.
- **Exxo-Labs/agent-tooling** changed: read its README and package.json for the install step.
  The binary is on PATH via pnpm global (`~/Library/pnpm/bin/agent-tooling`); the README says a
  global install is refreshed with `pnpm i -g @exxo-labs/agent-tooling` (the same package that
  `scripts/pnpm-globals` installs). Run what the docs say; the repo is not built here.
- **tmux-home** changed: `~/dev/dotfiles/scripts/tmux-plugins --update`. It builds from
  TPM's own clone (`~/.tmux/plugins/tmux-home`, moved by `update_plugins` from the pushed
  remote), not from `~/dev/tmux-home`, so a merged-and-pushed change is what arrives. The
  script then runs `cargo build --release` on it (incremental).
- **stray** changed: `scripts/cargo-update` installs it with
  `cargo install --git ssh://git@github.com/tim-codes/stray` (remote, not the local
  checkout), so the binary tracks pushed main. Re-run
  `CARGO_UPDATE_SKIP=tim-codes/squad ~/dev/dotfiles/scripts/cargo-update` once stray's main
  moved, e.g. after a merge. It reinstalls every other cargoGitDeps entry too, so althemer
  is refreshed as well.
- **althemer, worktrunk** (no checkout): updated only when `scripts/cargo-update` /
  `scripts/brew-update` run and the plugin refresh below covers the worktrunk marketplace.
  Upstream changes arrive no sooner than those runs.
- **homelab**: pull only. Its Ansible targets servers and is never run from here.
- **Exxo-Labs/skills**: pull only; the plugin refresh below covers it.

## f. Claude plugins, per context

Contexts: personal, reserve, exxo, exxo-personal, exxo-openrouter. exxo-personal and
exxo-openrouter share exxo's plugins dir, so update via exxo (four dirs, not five). Per
context use `command claude` (the shell wrapper pins personal):

```bash
env CLAUDE_CONFIG_DIR=~/.claude-<ctx> command claude plugin marketplace update
env CLAUDE_CONFIG_DIR=~/.claude-<ctx> command claude plugin update <plugin>@<marketplace>
```

Read plugin names from `~/.claude-<ctx>/plugins/installed_plugins.json`. Installs are
snapshots; running sessions need a restart to pick them up. Hand this sweep to a subagent.

## g. Final report: ONE checklist

Per repo: pulled old→new (or already current), installs/updates run. Per context: plugins
updated. PRs opened/merged. Other worktrees with unsaved work. Failed steps and declined prompts.

End with **Follow-up for you**: operator steps the run cannot do, each derived from what
actually changed; omit the section when there are none. Candidates:

- `rf` in any open fish shell (or `exec zsh`) when stowed shell config
  (`src/.config/fish`, `src/.zshrc`, `src/.config/shell`) changed;
- restart running Claude sessions after a claude-sync, plugin or skill change;
- a new terminal or app relaunch after brew cask updates;
- `tmux source-file ~/.tmux.conf` in a running tmux server (and reopen the tmux-home popup)
  after tmux-plugins or tmux config changed;
- PRs awaiting his review or merge decision.
