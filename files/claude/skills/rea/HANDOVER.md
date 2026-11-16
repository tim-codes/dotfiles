# Handover: rea skill (WIP)

Written 2026-11-16 when the work was wrapped up as-is. Delete this file
before the PR merges.

## Where things stand

- Goal: a codified, repeatable procedure for using rea (morluto/rea, npm
  `rea-agents`) and its companion tools in Tim's setup. The second test (reproduce a web app) ran on
  2026-11-16 and is codified; the native route is still open.
- First exercise: a mod that makes the in-game day 25-50% longer in Stardew
  Valley (Switch v1.6.15.13 in Astris). The stock timing is 7000 ms per 10
  in-game minutes; the target is 8750-10500 ms.
- Done: rea was assessed and its CLI works via npx; the game's ExeFS and
  RomFS were extracted to `~/rom/switch/extracted/stardew/`
  (`main.uncompressed` = 210 MB decompressed NSO); the save-patching skill
  exists at `~/rom/.claude/skills/stardew-save/` (game-specific, deliberately
  NOT in dotfiles).
- Blocker / pending Tim's call: the game is **AOT-native, not .NET**, so
  rea's built-in .NET analyser has nothing to read. The next step is choosing
  a native backend (Ghidra + a Switch NSO loader is the leading candidate,
  or Hopper/IDA/Rizin) before rea can locate the day-length constant in a
  stripped 210 MB image.

## Lost state - rebuild if needed

The original session's scratch helpers no longer exist (the temp scratchpad
was cleaned): `pfs0.py` (PFS0/NSP reader), `pfs0x.py` (NSP extractor),
`extract.sh`, `extract-b.sh`, `verify.py`, and the patched `hactool-src/`.
The hactool patch and calling convention are recorded in
`references/switch-titles.md`; the
helpers are small and can be rewritten. When rewritten, commit them as
scripts in this skill folder rather than leaving them in scratch.

## Next steps, in order

1. Get Tim's decision on the native backend. If Ghidra: install it, add it to
   `scripts/brew-update` `brewCasks` (+ JDK if needed) with a why-comment.
   Merge authority was granted for deps-manifest updates (2026-11-08).
2. Run rea against `main.uncompressed` with that backend; find the 7000 ms
   time-interval constant and check whether it varies by location.
3. Build the mod (exefs pchtxt/IPS keyed to the main NSO build id, or a
   cheat via Astris "Manage Cheats"); prove which mod root Astris loads.
4. Fold every proven native step into `references/switch-titles.md` and
   `SKILL.md`, remove the _unverified_ markers, and add the helper scripts.
5. Web-app test: **done 2026-11-16** against a hosted web editor (signed-in
   session over loopback CDP). Codified in `SKILL.md` and
   `references/web-apps.md`. A sibling `reproduce-web-app` skill for the
   end-to-end workflow is being written separately.

## Decided

- MCP: CLI-first for now. rea's tool catalogue is very large and the estate
  rule is MCP off by default. Registering it later would be an opt-in profile
  in the claude-sync MCP fragments, never `rea-agents setup`.

## Rules to carry forward

- Keep `~/rom/switch/stardew-modding/LOG.md` current (findings / decisions /
  procedures, dated). `references/stardew-worklog.md` here is a snapshot of
  it as of 2026-11-16.
- Never print key material; discard hactool output (see `references/switch-titles.md`).
- Work in a dotfiles worktree, never in the primary checkout (Stow
  symlinks live config from it). Use `claude-sync` to deploy; don't edit
  deployed copies.
- This branch is `wip/rea-skill`, worktree `~/dev/dotfiles-wip-rea-skill`.
