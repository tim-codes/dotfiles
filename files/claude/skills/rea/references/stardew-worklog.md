# Stardew (Switch / Astris) modding + rea tooling - work log

Running record of findings, decisions and working procedures. Append as the
work proceeds; keep entries dated. Feeds two later deliverables:

1. A codified, repeatable procedure for using `rea` and its companion tools in
   Tim's dev setup (skills under `~/rom/.claude/skills/`, installs persisted in
   the dotfiles deps manifests).
2. A next test: reproduce a web app using those skills (see "Next test").

## Goal

First example mod: make the in-game day 25-50% longer in real time on the
Switch build of Stardew Valley running in Astris (a Ryujinx fork). Stock is
7 s real time per 10 in-game minutes; target 8.75-10.5 s (7000 ms ->
8750-10500 ms). The mod is the vehicle for proving the rea workflow.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-11-07 | Save-file patching lives in a per-game skill, `~/rom/.claude/skills/stardew-save/` (SKILL.md + tested `grant.py`) | One skill folder per game Tim has Claude help with |
| 2026-11-08 | Use rea through its terminal CLI (`npx -y rea-agents@latest <cmd>`), from the scratch dir; do NOT run `npx rea-agents setup` | Setup edits agent configs/instructions; Tim's Claude config is assembled by `claude-sync` from dotfiles, so registration must be done there, deliberately, later |
| 2026-11-08 | Get the game code out via Astris "Extract Data" (ExeFS + RomFS), done by Tim in the GUI | Homebrew has no hactool/nstool; Astris already holds the keys and applies the update; nothing to install |
| 2026-11-08 | Defer installing Ghidra (cask + JDK) until we know the code is native, not .NET | Avoid a large install that may be unnecessary; if installed, persist in dotfiles deps manifests |
| 2026-11-08 | Layered-mod delivery preferred over exefs binary patch | Replacing a file under `mods/contents/0100e65002bb8000/<mod>/romfs/` survives game updates better and leaves originals untouched |

## Findings

- **Game files:** `~/rom/switch/titles/Stardew Valley/` holds `Stardew Valley US.nsp` (922 MB, title `0100e65002bb8000`, v0) and `Stardew Valley Update v1.6.15.13.nsp` (703 MB, patch id `0100e65002bb8800`). Both carry `.tik` tickets (title-key encrypted, KeyGeneration 3). Copies are in the session scratch dir (`.../scratchpad/sdv-src/`); originals untouched.
- **Container structure** (parsed with a small PFS0 reader, no tools): base = Program NCA 920 MB + Control + LegalInfo + Meta; update = one 700 MB NCA + two small ones. The 1.6.15.13 code is in the update, so any patch must target the update's contents.
- **Astris dir:** `~/rom/switch/astris/` has `Keys-22.1.0/{prod.keys,title.keys}` and empty `mods/{contents,exefs_patches,nro_patches}`. Never print key contents.
- **Switch NCA tooling:** no `hactool`/`nstool` in Homebrew (no formula, no tap). Building hactool from GitHub source in scratch was blocked by the permission classifier ("Code from External"); not worked around.
- **No native day-length setting** exists on any platform (forum moderator). PC mods (TimeSpeed, Nexus 6011 etc.) need SMAPI, which does not run on Switch/Ryujinx.
- **rea** (github.com/morluto/rea, rea.tools, npm `rea-agents`, MIT, v6.8.0 ran fine via npx):
  - MCP server + CLI, local analysis, evidence-backed results.
  - Needs Node 22.x >=22.23.4, 24.x >=24.22.1 or 26.12.1+. Active node is 24.21.0 (nvm); rea runs with only an EBADENGINE warning. Newer node may be wanted later.
  - Built-in static analysers relevant to us: **.NET assemblies** (metadata + CIL, no extra tools), IL2CPP metadata (Unity), packages/resources. Native binaries need Hopper, Ghidra, IDA or Kuna; offline objdump/Rizin supported but not installed by rea.
  - Official sources only: morluto/rea, rea.tools, npm rea-agents (README warns about look-alikes).
- **Astris UI (2026-11-08, screenshot):** the game right-click menu has NO "Extract Data" entry. It has Show in Finder, Manage Updates/DLCs/Cheats/Mods, Override Global Settings, Open Save Folder, Open Mods Folder (submenus), Open Shader Cache Folder, Copy Title ID, Clear Shader Cache. So the "extract via Astris" decision needs a fallback (check the top menu bar Actions menu; else hactool from source). "Manage Cheats" exists: runtime memory cheats are another delivery route, but still need the code address.
- **Astris web search (2026-11-08):** no docs or release notes found for Astris 1.0.22. Astris = Ryujinx-based Switch emulator for Apple-silicon Macs (macOS 15+), project page V380-Ori/Astris.Binaries (MIT). Stock Ryujinx/Ryubing has game right-click > Extract Data > ExeFS/RomFS/Logo (base + update only, no DLC); Astris 1.0.22 does not expose it. Conclusion: use hactool (SciresM/hactool) to extract from the NSPs; needs explicit approval because the classifier blocked the source build.
- **Astris mod folders (2026-11-08, screenshots + disk check):** right-click > Open Mods Folder offers two roots: **LayeredFS Mods** and **Atmosphère Mods**. Open Save Folder offers User / BCAT / Device Saves (User = our `bis/user/save`). On disk: LayeredFS root `~/rom/switch/astris/mods/contents/` (empty); Atmosphère root `~/rom/switch/astris/sdcard/atmosphere/contents/` holds an existing precedent, `010018e011d92000/Luminescent Platinum 2.2F SP/` (Pokemon Shining Pearl). So the layout is `<root>/<titleid>/<ModName>/{romfs,exefs}/`. Both roots are supported by Astris; which one it applies for Stardew still to be proven with the first mod. Stardew title id dir would be `0100e65002bb8000`.
- **Extraction result (2026-11-08, subagent + my verification):** hactool (SciresM, built in scratch, Oct 2023 commit) extracted the patched v1.6.15.13 data to `~/rom/switch/extracted/stardew/`: `exefs/` (main 85 MB NSO compressed, main.npdm, rtld, sdk 6 MB; no subsdk) and `romfs/` (588 MB, 3,554 files, `Content/` only), plus `main.uncompressed` (210 MB decompressed NSO). Stock hactool rejected the update NCA ("Invalid BKTR layout!", SDK 21.4.3): two edits to scratch `hactool-src/nca.c` relaxed the BKTR checks (subsection end `!= size` -> `> size`; the `total_size != header.offset` invalidation disabled). Caveat: 2 of 3,549 .xnb files (`Fonts/SpriteFont1.ja-JP.xnb`, `Fonts/SmallFont.ja-JP.xnb`) have no XNB magic (random-looking bytes) - possible patch-application error or genuine format; irrelevant to a code mod, unchecked.
- **Game code is NOT .NET assemblies:** zero .dll in romfs, no Managed dir, no `StardewValley.dll`. Build paths in the binary (`...\Stardew\stardew_console_mobile_1_6\Brute\Switch\bin\NX64\Release\StardewValley.nss`, `MonoGame/Switch/Brute/mono/mscorlib/...icall.cpp`) show a custom MonoGame/Mono port compiled ahead-of-time to native code. My scan of `main.uncompressed`: 0 CLI-metadata (`BSJB`) blobs, 0 PE (`MZ`) headers, 0 hits for `Game1`, `gameTimeInterval`, `realMilliSecondsPerGameTenMinutes`, `StardewValley.dll`; only 7 `mscorlib` strings. So rea's .NET analyser has nothing to read and the layered-romfs-DLL route is dead. Code changes must be native: an exefs binary patch (pchtxt/IPS keyed to the main NSO build id) or a cheat.
- **Save patching lessons** (details in the stardew-save skill): `parentSheetIndex` must be numeric; stacks cap at 999; both save slots are identical copies; patch only with the emulator closed; the game re-saves between sessions so always re-read.

## Procedures that work

- Parse an NSP: `scratchpad/pfs0.py` (PFS0 header reader, lists/reads files). Not yet saved anywhere durable - move into a skill when the rea procedure is codified.
- Run rea one-off: `cd <scratch> && npx -y rea-agents@latest <command> [args] --json`. Node warnings about engines are expected on 24.21.0.

- hactool on this machine (for codifying): run with keys passed as `-k <(filtered prod.keys)` (process substitution; hactool can't parse the 22.1.0 prod.keys' unknown lines), title key = 16 bytes at offset 0x180 of the `.tik` fed straight into `--titlekey=$VAR`, and ALWAYS discard hactool stdout+stderr (`>/dev/null 2>&1`): it prints key-file values in `[WARN] Failed to match key` lines and `-i` prints the title key.
- Scratch-only helper scripts from this run (move into a skill when codifying): `pfs0.py`, `pfs0x.py` (NSP extractor), `extract.sh`, `extract-b.sh`, `verify.py` in the session scratchpad; patched `hactool-src/` there too.

## Incident

- 2026-11-08: during extraction the subagent's tool output exposed key-file values and the update's (encrypted + decrypted) title key and NCA signatures in this session's transcript (not written to any file). Fixed going forward by discarding hactool output. Brief future delegations for hactool with the discard rule up front.

## Open questions

- ANSWERED: AOT-native (see Findings). Remaining: how to locate the day-length constant in a 210 MB stripped native image (names absent).
- Where is the 7000 ms value (`Game1` time interval) and does it vary by location (indoors/mines)?
- Which mod root does Astris actually apply for Stardew (LayeredFS `mods/contents` vs Atmosphère `sdcard/atmosphere/contents`)? Use "Manage Mods..." in the game menu to see what it detects; the Pokemon mod under Atmosphère is the working precedent.

## Status checklist

- [x] Save patching skill + tested script
- [x] rea assessed and CLI confirmed working
- [x] Brew options checked (none for hactool/nstool)
- [x] Decision: Astris has no extract option -> hactool from source in scratch, using Tim's keys (approved 2026-11-08; Manage Mods dialog shows "No Mods Found" for Stardew, as expected)
- [x] hactool build + ExeFS/RomFS extraction into `~/rom/switch/extracted/stardew/` (done 2026-11-08; save dir untouched)
- [ ] Decide the native route for the day-length constant (Ghidra + Switch NSO loader, or alternatives) - needs Tim's call
- [ ] Run rea on extracted code; locate day-length value; record managed vs native
- [ ] Build + test the day-stretch mod; record the exact layout that Astris loads
- [ ] Codify rea + tooling procedure into skills; persist installs in dotfiles
- [ ] Next test: reproduce a web app (below)

## Next test: reproduce a web app

Intent: after the rea procedure is codified, use rea (website/network/JS
analysis: page structure, scripts, network captures, source maps) plus the
helper skills to reproduce a web app. Open: which app, success criteria, where
the rebuild lives, what evidence trail we keep. Decide when we get there; the
log format here (findings / decisions / procedures) is the template.
