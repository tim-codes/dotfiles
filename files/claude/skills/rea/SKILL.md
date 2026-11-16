---
name: rea
description: "WORK IN PROGRESS - not yet a finished procedure. How to use rea (morluto/rea, npm rea-agents, \"reverse engineer anything\") on Tim's workstation - running its CLI one-off via npx, the rule against `rea-agents setup`, Node engine requirements, which analysers need extra tools (Ghidra etc.), and the Switch-title extraction procedure proven on Stardew Valley. Use when asked to reverse-engineer a binary, game, package or web app with rea, or to continue codifying this skill (read HANDOVER.md first)."
---

# rea - reverse engineer anything

> **Status: draft.** Codified from one partial run (Stardew Valley Switch
> day-length mod, Nov 2026). Sections marked _unverified_ have not been
> exercised end to end. Before extending, read `HANDOVER.md` in this folder
> and the full work log in `references/stardew-worklog.md`.

## What rea is

- MCP server + CLI that does local, evidence-backed analysis of binaries,
  packages, resources, websites/JS. MIT.
- **Official sources only:** github.com/morluto/rea, rea.tools, npm
  `rea-agents`. The README warns about look-alike packages - check the
  package name before running anything.
- Built-in static analysers need no extra tools for: .NET assemblies
  (metadata + CIL), Unity IL2CPP metadata, packages/resources, web
  (page structure, scripts, network captures, source maps - _unverified_).
- Native binaries need an external disassembler backend: Hopper, Ghidra, IDA
  or Kuna; offline objdump/Rizin is supported but not installed by rea.

## Running it

```bash
cd <scratch dir>                       # never inside a repo or the target's dir
npx -y rea-agents@latest <command> [args] --json
```

- Last confirmed version: 6.8.0 (2026-11-08).
- Node engines: 22.x >= 22.23.4, 24.x >= 24.22.1, or >= 26.12.1. On 24.21.0
  it runs with an `EBADENGINE` warning only. If a newer Node becomes
  necessary, persist it through dotfiles (nvm / `deps-up`), not ad hoc.
- **Do NOT run `npx rea-agents setup`.** It edits agent configs and
  instructions; Claude config on this machine is assembled by `claude-sync`
  from this repo. Registering rea as an MCP server is a deliberate,
  not-yet-made change to the MCP fragments here (see the
  `claude-workstation-setup` skill).

## Choosing the route: managed vs native

Find out what the code actually is before installing anything heavy:

1. Look for .NET metadata (`BSJB` blobs, `MZ`/PE headers, `*.dll`, a
   `Managed/` dir) or IL2CPP `global-metadata.dat`. If present, rea's
   built-in analysers work with no extra installs.
2. If none of that is present (AOT-compiled, e.g. Switch MonoGame ports),
   it's native: a disassembler backend is needed. Ghidra (cask + JDK) is the
   leading candidate. Install it only once this is confirmed, and persist it
   in `scripts/brew-update` (`brewCasks`) with a why-comment.

## Procedure: extracting a Nintendo Switch title (proven)

Homebrew has no `hactool`/`nstool`. Astris 1.0.22 (Ryujinx fork) has no
"Extract Data" menu, unlike stock Ryujinx. Working route:

- Build SciresM/hactool from source in a scratch dir. For SDK 21.x update
  NCAs, stock hactool fails with `Invalid BKTR layout!`; two edits in
  `nca.c` fix it: subsection end check `!= size` -> `> size`, and disable
  the `total_size != header.offset` invalidation.
- Keys: pass `-k <(filtered prod.keys)` (process substitution; hactool
  can't parse unknown lines in newer key files). Title key = 16 bytes at
  offset 0x180 of the `.tik`, passed as `--titlekey=$VAR`.
- **ALWAYS discard hactool stdout+stderr (`>/dev/null 2>&1`).** It prints
  key values in `[WARN] Failed to match key` lines, and `-i` prints the
  title key. A subagent leaked key material into a transcript on
  2026-11-08 because of this; restate the rule in any delegation brief.
- Never print key files. Reference them by path only.
- Layered mods: `<root>/<titleid>/<ModName>/{romfs,exefs}/`, under
  `~/rom/switch/astris/mods/contents/` (LayeredFS) or
  `~/rom/switch/astris/sdcard/atmosphere/contents/` (Atmosphere). Which root
  Astris applies for a given title is _unverified_.

## Open work

See `HANDOVER.md`.
