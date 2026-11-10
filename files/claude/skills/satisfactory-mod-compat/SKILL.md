---
name: satisfactory-mod-compat
description: Keep the modded Satisfactory install on its pinned game build — freeze a queued Steam update before it downloads, revert one that already landed, and diagnose mod load failures by PE import resolution. Use when Steam queues a Satisfactory update, when the game crashes at startup with "Plugin 'X' failed to load", or before accepting any mod update.
---

# Satisfactory mod compatibility

Windows gaming box only. The install is deliberately held on an old game build
because native mods are compiled against it. Mod version metadata is unreliable,
so **diagnose by symbol resolution, never by declared compatibility**.

Paths are hardcoded at the top of each script (`D:\SteamLibrary\...`, app 526870,
depot 526871). Change them there if the library moves.

## The pin

| | |
|---|---|
| Pinned build | CL 495413 / BuildID 23855724 / depot manifest `4539050184413547681` |
| Restore source | `C:\Program Files (x86)\Steam\steamapps\content\app_526870\depot_526871` (~29 GB) |
| Mod versions | recorded in `FactoryGame\Mods\<profile>-lock.json` |

**Never delete the restore source** — without it a revert costs a 29 GB download.

## Why mods break

Mods on ficsit.app declare open-ended compatibility (`"GameVersion": ">=491125"`)
and authors don't raise the lower bound when they rebuild against a newer CL. A
mod compiled for a later build still advertises itself as valid for the pinned
one, SMM resolves it, installs it, and the game dies at startup. There is no
manifest fix — SMM reads the real game version correctly; the mods are wrong.

## Decision

- Steam update **queued, not yet downloaded** → freeze it (below). Preferred.
- Steam update **already applied** → revert the game.
- Game crashes after a **mod** change → scan, then roll the mods back.

## Freeze a queued update

Steam must be **fully closed** — it holds app state in memory and rewrites the
`.acf` on exit, silently undoing the edit.

```powershell
& "C:\Program Files (x86)\Steam\steam.exe" -shutdown
```

```bash
python scripts/freeze-steam-update.py
```

Rewrites `appmanifest_526870.acf` to claim the pending build: `buildid` :=
`TargetBuildID`, depot `manifest` := the new manifest Steam already prefetched
into `depotcache`, `StateFlags` := 4 (drops "Update Required"), and zeroes the
`Bytes*` / `ScheduledAutoUpdate` fields. Backs the `.acf` up first; idempotent
(aborts when `TargetBuildID == buildid`). Restart Steam and confirm no update is
queued.

Claiming the *pending* build is the point. Leaving the manifest on the
last-pushed build is what let the 2026-10-15 release through.

## Revert an applied update

```powershell
powershell -ExecutionPolicy Bypass -File scripts\revert-game.ps1
```

Renames the current install aside, copies CL 495413 back from the restore
source, then carries `FactoryGame\Mods` across so pinned mod versions survive.
Preflights source BuildId, game process and disk space. Leaves the replaced
build alongside as `Satisfactory-<buildid>`; delete it once the session is good.

## Diagnose mod load failures

```bash
python scripts/scanall.py
```

Indexes every provider DLL in the install, then reports each deployed mod DLL
with unresolved imports.

## Interpreting results

- `GetLastError=127` (proc-not-found) = **that** mod is stale. `126`
  (module-not-found) = a *dependency* failed first. **Chase the 127.** The crash
  dialog names whichever plugin failed last, usually a victim.
- Missing `*Legacy*` build-effect symbols (`OnLegacyBuildEffectFinished`,
  `PlayLegacyBuildEffect`, `SetPlayingBuildEffectActor`) mean the mod was built
  for a newer CL than the pin.
- An entry with **0 unresolved** and `(dll absent)` is a false positive — a
  provider DLL outside the indexed paths. Only non-zero counts are findings.
- Clean result reads `ALL DEPLOYED MOD DLLs RESOLVE CLEANLY`.

## Rolling mods back

Old versions stay in `%LOCALAPPDATA%\ficsit\downloadCache`, so a rollback is
offline: delete the deployed mod dir, re-extract the older zip, update the
lockfile. Roll back a mod's whole lockstep family, not just the broken one —
dependency constraints are permissive (`^`, `>=`) and will re-resolve forward.

When hand-editing `<profile>-lock.json`, write **UTF-8 without BOM**.
`Set-Content -Encoding utf8` on PowerShell 5.1 adds a BOM and ficsit-cli (Go)
then fails with `invalid character 'ï' looking for beginning of value`.

## Rules

- **Never run "Verify integrity of game files"** — it detects the manifest
  mismatch and re-downloads immediately.
- **Never press "Update All"** in SMM. Individual "Ignore" is fine.
- The lockfile is the real pin: ficsit-cli preserves locked versions across
  profile changes (npm/cargo style), so adding a mod does *not* drag everything
  to latest. Per-dependency UI pinning is unnecessary.
- Freezing means Steam believes it is on the newest build: no real update
  without restoring the `.acf` backup, and no multiplayer with anyone current.
