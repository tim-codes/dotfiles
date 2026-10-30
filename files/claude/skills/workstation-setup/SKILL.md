---
name: workstation-setup
description: Lightweight start-of-day check that makes this machine ready to work — read-only dev-stack status, claude-sync drift, container runtime, logins via claude-reauth, optional squad/worktree checks, ending in "ready" or "needs X". Minutes, not hours. Not claude-workstation-setup (which explains how the Claude setup works) and not workstation-sync (the heavy pull/merge/install update). Use when Tim says "start of day", "get ready to work", "set up this machine for work", "/workstation-setup".
---

# Workstation setup: ready to work

A short checklist. It reports and fixes auth; it never pulls, merges or installs
(that is `workstation-sync`). Dev stack checkouts: `~/dev/dotfiles`, `~/dev/squad`,
`~/dev/homelab`, `~/dev/exxo/skills`, `~/dev/exxo/agent-tooling`, `~/dev/tmux-home`,
`~/dev/oss/stray` (`workstation-sync` holds the canonical inventory).

## Output rule (governs the whole run)

Run silently: no per-step narration, no intermediate tables. Speak mid-run only for
(a) errors and failures; (b) decisions Tim must make; (c) a heads-up just before a prompt
he must answer (Touch ID, browser OAuth, device code). Delegate noisy steps to a
subagent so only its conclusion reaches you. Finish with ONE summary (step d).

Environment: SSH remotes only; never print secrets; a hung-looking command is probably
waiting on Tim's prompt, so wait generously (10+ minutes) and never kill or auto-cancel it.
Use `git -C <dir>` and absolute paths.

## a. Read-only status

- Per dev-stack primary checkout: `git -C <dir> fetch --prune`, then on main? clean? behind or
  ahead of `origin/main`? If any is behind, dirty or off main, recommend `workstation-sync`;
  do not fix it here.
- `~/dev/dotfiles/scripts/claude-sync --diff` run from the dotfiles primary checkout: clean?
  Drift means recommend `workstation-sync` (or `claude-workstation-setup` to understand it).
- OrbStack/Docker up: `claude-reauth` in step b starts it; don't start it separately.

## b. Auth

1. `~/dev/dotfiles/scripts/claude-reauth --check --context all` (covers personal, reserve,
   exxo, exxo-personal). Keep the table for the summary; show it only if something needs auth.
2. If anything needs auth, tell Tim what will appear (browser OAuth windows, Touch ID, device
   codes), then run `~/dev/dotfiles/scripts/claude-reauth --context all` in the background and
   wait. Follow the `reauth` skill for the details: rows needing a terminal (`gh auth login`,
   `pulumi login`, ...) go to Tim as exact commands, and MCP steps are per-context `/mcp`.

## c. Optional quick checks (report only)

- Squad broker reachable: `squad doctor` WITHOUT `--fix` (read-only). Never restart anything.
- Stale worktrees: count from `git -C <dir> worktree list` per dev-stack repo (merged or
  clean ones are candidates for `worktree-closedown`). Do not touch them.

## d. Summary

ONE table: dev stack, claude-sync, containers, logins, squad, worktrees. Then **ready** or
**needs X**. Then **Follow-up for you**, derived from what was found (omit when empty):

- run `workstation-sync` when a checkout is behind, dirty or off main, or claude-sync drifted;
- logins still pending from reauth (exact commands);
- restart running Claude sessions after claude-sync changes;
- squad broker restart if `squad doctor` says it is stale.
