# ADR: Firefox resource containment — codified prefs plus an external watchdog

Date: 2026-08-22
Status: Accepted

## Context

Firefox on this workstation repeatedly ran away with CPU and memory. A probe
on 2026-08-22 found the machine at load ~6 on 12 cores with swap at 11 GB of
12 GB and 85 MB of physical memory unused, while 23 tabs occupied 40 content
processes.

Sampling the hottest content process put ~94% of its samples in
unsymbolicated JIT frames — a page's own JavaScript spinning, not layout,
graphics, or a Firefox defect. Two sites were confirmed as repeat offenders:

- **GanttPRO** — 110% CPU (>1 core) within 52 seconds of a cold browser start,
  before any interaction, because it is a *pinned* tab.
- **UniFi Network controller** (`https://unifi`, Client Devices) — ~0.6–1.4
  cores sustained; it holds a websocket and re-renders a large device table
  indefinitely whether or not it is in the foreground.

Separately, a Spaceship "Buyer Hub" tab held 2 GB resident at 0.03% CPU — a
leak rather than a working set, and the single largest contributor to the
swap exhaustion.

Two distinct problems, needing two mechanisms.

## Decision

### 1. Codified prefs via `user.js`

`src/.config/firefox/user.js` holds the prefs; `scripts/firefox-prefs`
symlinks it into each installation's active profile. Because it is a symlink,
editing the repo file is sufficient — the linker only needs re-running when a
new profile or machine appears.

The pref that matters is
`browser.sessionstore.restore_pinned_tabs_on_demand = true`. Firefox restores
normal tabs lazily (`browser.sessionstore.restore_on_demand` defaults true)
but pinned tabs **eagerly** (this pref defaults false, verified in
`Firefox.app/.../browser/omni.ja:defaults/preferences/firefox.js:521` on
153.0.4). A pinned heavy SPA therefore executes at every launch, unprompted.
That single default explains the post-start CPU spike exactly.

Profile resolution reads the `[InstallXXXX]` sections of `profiles.ini`, not
the `Default=1` flag on a `[ProfileN]` section. On this machine those
disagree — the Profile flag points at a stale `default` profile while release
Firefox honours its Install entry — so using the obvious-looking flag would
silently write prefs into a profile nothing loads.

### 2. External watchdog via launchd

`src/bin/firefox-tab-watchdog`, run by
`src/Library/LaunchAgents/dev.tim.firefox-tab-watchdog.plist`.

This has to live outside the browser. Firefox exposes no per-tab CPU limit,
and no WebExtension API reports per-process CPU, so no add-on can either see
or stop a runaway — extensions can only discard tabs on an *inactivity*
timer, which by construction misses a tab you are actively looking at. Only
a process outside the browser has the accounting to act on.

It measures CPU as a delta of consumed CPU time between samples. The `ps
%cpu` column is a lifetime average, so a tab that spiked an hour ago reads
hot forever and would trip a naive check permanently.

Default mode is `warn` (log and notify, no kill). Enforcement is opt-in via
the plist's `FF_WATCHDOG_MODE`, after the log has demonstrated it flags the
right processes. Killing a content process is itself low-risk: Firefox
replaces the tab with a restorable "tab crashed" page and loses no session
state.

## Consequences

- Prefs set in `user.js` are authoritative. Changing them in `about:config`
  holds for the session only and resets at restart — the repo is the place to
  change them. This is the intended trade and is called out in the file.
- The first LaunchAgent in this repo. `src/Library/LaunchAgents/` stows into
  the existing real `~/Library/LaunchAgents/`, so Stow tree-folding leaves the
  directory alone and symlinks only our plist alongside the 19 vendor agents
  already there.
- The watchdog cannot name the site it flags. Fission sandboxes content
  processes with no file or socket handles that identify their origin, so
  pid → URL is only resolvable inside the browser. The warn notification
  therefore tells the operator to open `about:processes`, which is the only
  place that mapping exists.
- Firefox's **extension process is indistinguishable from a web tab** by argv
  (both `-isForBrowser tab`). The watchdog excludes the lowest child id
  among tab processes, which is reliably the extension process because it is
  spawned before any web content — a heuristic, not a guarantee. A mis-fire
  is recoverable (extensions reload); `FF_WATCHDOG_EXCLUDE_PIDS` is the
  escape hatch.
- Not adopted: capping `dom.ipc.processCount`. Under Fission, process count is
  a function of per-origin site isolation; capping it trades a security
  boundary for memory, which is the wrong trade here.
- Auto Tab Discard is installed alongside this to handle the long tail of
  merely-idle tabs. It excludes pinned tabs by default, so that needs enabling
  for the pinned ones to be covered.
