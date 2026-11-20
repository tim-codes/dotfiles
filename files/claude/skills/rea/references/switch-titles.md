# Extracting a Nintendo Switch title (proven)

Moved out of `SKILL.md`. Proven on Stardew Valley (Nov 2026); see
`stardew-worklog.md` for the full log.

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
