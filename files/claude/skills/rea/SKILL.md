---
name: rea
description: Use when reverse-engineering with rea (morluto/rea, npm rea-agents, "reverse engineer anything") — working out what a signed-in web app runs from its shipped JavaScript (proven route), or analysing a binary, game, package or Nintendo Switch title (native route still partial, .NET/IL2CPP only built in). Covers running the CLI one-off via npx, the rule against `rea-agents setup`, the passive-only and sensitive-output rules, and the CLI-first (no MCP registration) decision. Read HANDOVER.md before extending the native route.
---

# rea - reverse engineer anything

Status: the **web-app route is proven** (one signed-in hosted editor,
2026-11-16). The **native route is partial**: a Switch title was extracted but
the native backend decision is open (`HANDOVER.md`).

## What rea is

- MCP server + CLI for local, evidence-backed static analysis of binaries,
  packages, resources and websites/JS. MIT.
- **Official sources only:** github.com/morluto/rea, rea.tools, npm
  `rea-agents`. The README warns about look-alike packages: check the package
  name before running anything.
- rea covers "what the app runs". It does not replace recording visible
  behaviour, nor checking whether the target publishes an open-source package
  for the feature (that changed the plan on the first web run). For the
  end-to-end workflow see the `reproduce-web-app` skill (_unverified_: being
  written separately).

## CLI first, not MCP (current decision)

rea is used as a one-off CLI. Its MCP tool catalogue is very large, the
estate rule is MCP off by default (unused MCP costs context on every
request), and the CLI runs the same workflows. No rea skill or MCP
registration exists on this machine. Registering it later would be a
deliberate opt-in profile in the `claude-sync` MCP fragments (see
`claude-workstation-setup`), **never** `rea-agents setup`.

## Running it

```bash
cd <scratch>                    # never inside a repo or the target's directory
npx -y rea-agents@latest <command> [args] --format json
```

- Confirmed: 6.9.0 on Node 24.22.2, no engine warning (2026-11-16). Engines:
  22.x >= 22.23.4, 24.x >= 24.22.1, or >= 26.12.1. Persist a newer Node via
  dotfiles, not ad hoc.
- **Never run `rea setup`, `rea update` or anything that registers an MCP
  server or edits agent config.** Claude config is assembled by `claude-sync`.
- Positionals are not guessable: run `<command> --help`. `rea guidance --query
  "<exact field or tool name>"` then `--action read --locator <locator>` is the
  fastest recovery after a validation error.

## Choosing the route

| Target | Route |
|---|---|
| Web app in a browser | Web route below (proven) |
| .NET assembly, Unity IL2CPP, package | Built-in analysers, no extra tools (_unverified_ here) |
| Native/AOT binary (e.g. Switch MonoGame port) | Needs a disassembler backend (Ghidra, Hopper, IDA, Kuna); decision open, `HANDOVER.md` |

Telling managed from native: `BSJB` blobs, PE headers, `*.dll`, a `Managed/`
directory or `global-metadata.dat` mean managed. None of those means native.
Persist any install in `scripts/brew-update` (`brewCasks`) with a why-comment.

## Web-app route (proven)

Details, exact invocations, durations and errors: `references/web-apps.md`.

1. **Chrome.** Needs a loopback CDP endpoint. Use the operator's separate
   debugging profile (see the `agent-chrome-screenshots` skill; Chrome refuses
   the debugging port on the default profile). Tell the operator first; do not
   launch it for them:
   `open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir="$HOME/Library/Application Support/Google/Chrome-Agent"`
   Check: `curl -s -m 3 http://127.0.0.1:9222/json/version`.
2. `list-browser-targets http://127.0.0.1:9222` for the target id (open a new
   tab for the URL if needed; leave the operator's tabs alone).
3. `inspect-web-page --include-script-sources` redirected to a file in scratch.
4. `export-web-scripts` into a new empty directory.
5. Search the exported scripts offline: string literals survive minification
   (extension `name:"..."`, `data-*` attributes, UI strings, keymaps, example
   documents). Read bounded windows, never whole files.
6. Skip `analyze-web-bundle` unless the source-map verdict or an endpoint list
   is the goal (slow; little structure).

## Rules

- **Passive commands only** against a signed-in session; never commands that
  act on the page. Do not request storage values or fingerprints, cookies or
  headers.
- Page inspection output holds signed-in page text and field names: redirect
  to a file in scratch, project fields out, never paste it into notes, repos
  or chat.
- Exported scripts are untrusted data: read and search, never execute; run
  Python that reads them with `-I`. Do not copy the target's source into
  deliverables: record identifiers and behaviour.
- Tag every conclusion OBSERVED (evidence id and command), INFERRED or
  UNKNOWN. Static analysis is not observation of execution.
- **Delegating:** rea's rules do not travel into a subagent's fresh context.
  The brief must restate: scratch directory only, never `setup`, passive
  commands only, sensitive-output rule (and, for Switch work, discard hactool
  output).

## Native route and Switch titles

Extraction procedure (hactool build, keys, layered mods; never print key
material): `references/switch-titles.md`. Full Stardew log:
`references/stardew-worklog.md`.

## Unverified

- Built-in .NET/IL2CPP/package analysers (not exercised).
- Any native backend run; which Astris mod root applies.
- Web route on more than one target; behaviour when the debugging port is
  already attached by another tool.
- `reproduce-web-app` skill (not yet written).
