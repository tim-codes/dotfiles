# macOS privacy (TCC) grants and the tmux server

Status: draft, 2026-10-28. Findings marked **unverified** have not been
confirmed on this machine yet; see "Test plan" at the end.

## Symptoms

Processes running in tmux panes lose macOS privacy grants after every
`brew upgrade tmux`:

- **Local Network** - non-Apple binaries (Homebrew python, curl, ...) get
  `EHOSTUNREACH` / "No route to host" to LAN hosts, while Apple-signed ones
  (`/usr/bin/nc`, `/usr/bin/curl`, `/usr/bin/ssh`) work.
- **App data** - "“op” would like to access data from other apps" keeps
  reappearing when the 1Password CLI talks to the desktop app.
- **Full Disk Access** - a path only FDA can read (`~/Library/Safari`,
  `~/Library/Mail`, `TCC.db`) answers "Operation not permitted" from a pane
  even after tmux has been added to the FDA list.

## Root cause

TCC does not grant to the process that asks; it grants to the *responsible
process*, the process launchd started that the asker descends from. Every
pane shell, and every child of `tmux run-shell`, descends from the tmux
**server**, so the server is the responsible process. The unified log says so
directly (`/usr/bin/log show --predicate 'subsystem == "com.apple.TCC"'`,
2026-10-28 06:59, `op` asking for app data from a pane):

    responsible={identifier=tmux-55554944060659f0327736588e15becf60db7114, ...}
    accessing={identifier=com.1password.op, binary_path=/opt/homebrew/Caskroom/1password-cli/2.41.1/op}

Two things then make the grant fragile:

1. **Homebrew's tmux is ad-hoc signed.** `codesign -dv` shows
   `Signature=adhoc`, no Team ID, and an identifier of the form
   `tmux-5555...<hash>` derived from the binary's code directory hash. TCC
   keys the grant on that identity, so each release is a different
   application to TCC. The grant has to be made again for every version.
2. **The server outlives the binary.** `brew upgrade` deletes the old Cellar
   directory, but the server keeps running from the unlinked file. Seen on
   2026-10-28: server pid 910 started 2026-10-20 03:05 from
   `/opt/homebrew/Cellar/tmux/3.7c/bin/tmux` (`lsof -p 910` still maps it);
   brew installed 3.8 at 06:16 the same morning and 3.7c is gone from the
   Cellar. The grant Tim added that day went to the only tmux that exists on
   disk, 3.8 (`TCCAccessSetInternal ... client=/opt/homebrew/Cellar/tmux/3.8/bin/tmux`
   at 07:01:45), while every pane is still answered for identity
   `tmux-...7114`, the 3.7c server. A new grant therefore takes effect only
   once the server is restarted on the new binary; and a prompt answered
   "Allow" for the stale identity has nothing on disk to verify against,
   which is the likely reason the `op` prompt comes back (**unverified**).

The two "tmux" rows in the FDA list are two different tmux identities
(two versions); only the one matching the installed binary can ever match
again, and only after a server restart.

The job that starts the server (`src/Library/LaunchAgents/dev.tim.tmux-server.plist`)
runs `/bin/zsh -lc '... exec tmux new-session -d ...'`. Because zsh `exec`s
tmux, the launchd job process *is* tmux, which is why tmux (not zsh) is the
responsible identity. Ghostty, which only attaches, is not involved.

Local Network is not a TCC service on macOS 26 (`tccd` carries no
`kTCCServiceLocalNetwork` string), so its denials do not appear in the TCC
log; the same responsible-process rule is assumed to apply (**unverified**).

## Check it: `macos-privacy-check`

`src/bin/macos-privacy-check` (on PATH as `~/bin/macos-privacy-check` once
stowed) tests what pane processes can actually do, by running the probes
through `tmux run-shell` so they are children of the server. It never reads
`TCC.db` (that needs FDA itself) and never touches app-data paths (that
raises the prompt the check exists to avoid).

Checks, each printed as `PASS`/`FAIL`/`SKIP` with a reason, exit 1 on any
FAIL, 2 if a check was inconclusive and nothing failed:

- `server-binary` - the running server's executable is the installed tmux.
  FAIL means a `brew upgrade` has happened since the server started and no
  grant can reach the panes until it is restarted.
- `full-disk-access` - `/bin/ls ~/Library/Safari` (then `~/Library/Mail`)
  from the server's context. "Operation not permitted" means no FDA; FDA is
  deny-silent, so this never raises a dialog.
- `local-network` - a non-Apple binary (Homebrew python3 or curl) opens a TCP
  connection to a LAN host from the server's context. `EHOSTUNREACH` means
  the Local Network grant is missing; refused or connected means it is there.
  An Apple-signed `/usr/bin/nc` reaches the same host first as a control: if
  it cannot, the target is down and the check is inconclusive, not a drift.
  Target: `--target HOST[:PORT]`, `$PRIVACY_CHECK_LAN_TARGET`, else the
  default gateway on port 80. Note: the first attended run may raise the
  Local Network prompt itself, if the responsible process has never been
  asked; that is the one prompt worth answering.

Flags: `--notify` posts a macOS notification on drift (what the daily job
uses); `--fix` additionally offers, in a dialog, to open the right System
Settings pane and reveal the binary to add; `--dry-run` prints what `--fix`
would open without opening anything; `--wait SECS` waits for the server
(login race). `--help` has the rest.

The check does not change any setting. TCC.db is SIP-protected, PPPC
profiles need MDM, and UI-scripting System Settings is out of bounds.

## Re-grant manually

1. Run `macos-privacy-check`; if `server-binary` fails, restart the server
   first so the grant goes to the identity the panes will use. That kills
   every session: let tmux-resurrect save (`C-a C-s`), then
   `tmux kill-server; launchctl kickstart -k gui/$(id -u)/dev.tim.tmux-server`.
2. System Settings > Privacy & Security > Full Disk Access: `+`, then
   `Cmd-Shift-G` and paste the path `macos-privacy-check --dry-run` prints
   (the resolved `/opt/homebrew/Cellar/tmux/<version>/bin/tmux`, not the
   `/opt/homebrew/bin/tmux` symlink). `macos-privacy-check --fix` opens the
   pane and reveals the file in Finder for drag-and-drop.
3. Remove the other "tmux" rows: they are older identities and never match
   again.
4. Local Network and app data have no `+` button; they are populated by the
   prompt. With the server on the installed binary, run the thing that
   prompted (`op`, the LAN tool) once from a pane and answer Allow.
5. `macos-privacy-check` again: all PASS.

Deep links (macOS 13+ form, anchor names **unverified** on macOS 26; the
bundle id is confirmed from `/System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex`):
`x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles`,
`...?Privacy_LocalNetwork`. Override with `$PRIVACY_CHECK_SETTINGS_URL` if
the anchor lands on the wrong pane.

## Daily check

`src/Library/LaunchAgents/dev.tim.macos-privacy-check.plist` runs
`macos-privacy-check --notify --wait 120` at 09:30 and at login. It logs to
`~/Library/Logs/macos-privacy-check.log` and only notifies on drift. When no
server is running it logs that and exits 0. Activate after merging:
`restow`, then `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.tim.macos-privacy-check.plist`.

## Root fix options (decision pending)

| Option | Survives `brew upgrade` | Pros | Cons |
|---|---|---|---|
| **A. Re-sign tmux after each upgrade** with a stable local identity (self-signed cert in the login keychain, fixed identifier) | Yes, once re-signed; the grant keys on identifier + certificate, not cdhash or path | No change to how the server starts | Needs a cert; a re-sign step after every `brew upgrade tmux` (brew has no post-upgrade hook; `deps-up` could do it); still needs a server restart per upgrade, since the old binary is unlinked anyway |
| **B. Stable launcher** - the plist starts a tiny Mach-O stub (built once, ad-hoc or self-signed, never rebuilt, e.g. `~/Applications/TmuxServer.app`) that spawns tmux as a *child* (no `exec`) and waits | Yes: the responsible identity is the stub's, tmux's identity never matters | One grant for good; works for every future tmux; no cert required if ad-hoc, because the stub's cdhash never changes | A compiled stub to keep in the repo; whether responsibility still resolves for the server after the stub exits is **unverified**, so the stub waits on the server (trivial) |
| **C. Make `/bin/zsh` or Ghostty responsible** (drop the `exec`, or let Ghostty start the server) | Partly | zsh is an Apple platform binary with a stable identity; Ghostty is Developer ID signed (team 24VZTF6M5V) and already in FDA | Granting FDA/Local Network to every zsh on the machine is far broader than wanted; with Ghostty the server depends on the terminal winning the login race and its identity changes with Ghostty updates (less often, but still) |

Recommendation: **B**. It is the only option where a tmux upgrade is a
non-event for TCC, and it keeps the grant scoped to one purpose-built
binary. A is the fallback if B's responsibility propagation does not hold in
testing. Either way the first switch needs one server restart and one
re-grant.

## Test plan (attended, in order)

Everything below is untested on this machine except the facts under "Root
cause". Run from the worktree without stowing:
`~/dev/dotfiles-feat-macos-privacy-check/src/bin/macos-privacy-check`.

1. `macos-privacy-check --help` and `--dry-run`: the resolved tmux path and
   the Settings URLs print; nothing opens.
2. `macos-privacy-check`: expect `FAIL server-binary` (3.7c vs 3.8) and
   `FAIL full-disk-access` today. The `local-network` probe talks to the
   gateway on port 80 by default; pass `--target 192.168.30.202:3000` (or any
   LAN host that answers) to test against something known. The first run may
   raise a Local Network prompt: that is expected, answer it.
3. `macos-privacy-check --fix`: a dialog, then System Settings should land
   on Privacy & Security > Full Disk Access and Finder should reveal
   `/opt/homebrew/Cellar/tmux/3.8/bin/tmux`. If Settings opens on the wrong
   pane, the anchor name is wrong: set `PRIVACY_CHECK_SETTINGS_URL`.
4. Save sessions, restart the server, re-run the check: `server-binary`
   should PASS, and `full-disk-access` should PASS because the 3.8 grant now
   matches. Remove the stale "tmux" row.
5. Confirm that `sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" .tables`
   from a pane now works, and that `op` no longer prompts.
6. `plutil -lint` the new plist, `restow`, `launchctl bootstrap` it, then
   `launchctl kickstart gui/$(id -u)/dev.tim.macos-privacy-check` and read
   `~/Library/Logs/macos-privacy-check.log`.
