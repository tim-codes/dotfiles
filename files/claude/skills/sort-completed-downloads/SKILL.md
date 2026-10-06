---
name: sort-completed-downloads
description: Use when asked to move/sort/organize completed Transmission downloads on ragnar into the Plex library (movies or TV shows), or when checking what's finished downloading and ready to file.
---

# Sort Completed Downloads (ragnar)

## Overview

Transmission on ragnar lands finished files directly in
`/mnt/tank/common/transmission/downloads/` (per-file, as each completes -
`incomplete-dir-enabled` means a multi-file torrent can have some files done
and others still `*.part` in the same folder). This skill files those
finished releases into the Plex library at `/mnt/tank/media/`, classifying
each as a movie or a TV episode and placing it per the library's existing
conventions.

**Script:** `projects/ragnar-v3/scripts/sort-completed-downloads.sh` (runs ON ragnar).

## Library conventions it targets

- Movies: flat files (no per-movie subfolder) at
  `Movies/<2160p|1080p|other>/<A-Z|0-9|#>/<name>.<ext>`. Subtitles sit
  alongside with a matching basename. Letter bucket = first character of
  the destination filename (article "The" is NOT stripped).
- TV: `TV Shows/<2160p|1080p|other>/<Show>/Season <N>/<Show> SxxEyy.<ext>`
  (no letter buckets). A show is not split across resolution tiers - if it
  already exists under one tier, new episodes join it there.
- The existing library has zero `www.*`-prefixed filenames - torrent-site
  ad prefixes ("www.UIndex.org    -    Title") are always stripped on import.
- File extensions are matched **case-insensitively everywhere** - releases
  ship `.MKV`/`.Mp4`/`.SRT` as readily as lowercase, and a case-sensitive
  match misclassifies silently rather than erroring. TV destination filenames
  are rebuilt with a lowercased extension; movies keep their filename verbatim.

## Running it

```bash
# One-time per control Mac, if ssh fails with "Too many authentication
# failures": the 1Password agent offers 7+ keys and trips MaxAuthTries.
# This pins the ragnar key in ~/.ssh/config (fixes ansible/just too):
projects/ragnar-v3/client-config.sh

scp projects/ragnar-v3/scripts/sort-completed-downloads.sh ragnar:/tmp/
ssh ragnar "bash /tmp/sort-completed-downloads.sh --dry-run"   # review first
ssh ragnar "bash /tmp/sort-completed-downloads.sh --detach"    # then execute
```

**Always pass `--detach` for a real run.** It forks the work into a session-
independent process on ragnar and returns immediately, printing a pid and a
log path. Without it the copy is a child of the ssh session, so anything that
takes the caller's terminal away - an agent's background task being reaped,
a dropped link, Ctrl-C - kills it partway through a file. Follow it with:

```bash
ssh ragnar "tail -f /tmp/sort-completed-downloads.<stamp>.<pid>.log"
```

`--detach` also runs from a timestamped private copy of the script, so the
"never re-scp mid-run" hazard below no longer applies to a detached run.

If a run *is* interrupted, audit before resuming rather than assuming: moves
are `rsync --remove-source-files`, so an interrupted file leaves a short
destination that the script will refuse to overwrite on the next pass (it
logs a conflict and keeps the source). Compare sizes for every planned move -
src gone = done; src and dest both present with equal size = fine; unequal =
partial, delete the destination before resuming. Re-running the same
`--apply-plan` is otherwise safe and picks up where it left off.

If scp fails with "Received message too long", a shell startup file on ragnar
is printing on non-interactive sessions again. Fix it at the source; as a
stopgap, push via ssh stdin: `ssh ragnar "cat > /tmp/x.sh" < local.sh`.

Where to look, in the dotfiles repo: zsh is the login shell on Linux
(`scripts/setup-linux` runs `chsh -s $(which zsh)`), so a non-interactive
`scp`/`ssh` session reads **`.zshenv` → `~/.config/shell/common.sh`** and
nothing else. That shared file must stay silent — it is also sourced by
`.bashrc` above its interactive guard. Any `echo` belongs *below* that guard,
which is what dotfiles `1a59046` fixed for `.bashrc`.

Always dry-run first and read the plan. `/mnt/tank/common` and
`/mnt/tank/media` are separate ZFS datasets, so moves are real copies (slow
for large batches, not instant renames) - expect it to run long and use
Bash's `run_in_background` rather than a short timeout.

**Never re-`scp` the script while a run is in progress.** Bash reads a script
incrementally as it executes; overwriting it mid-run makes the shell resume at
a byte offset in the new file and die with a bogus syntax error partway
through. Copy it to a unique path if you need to test edits during a long run.

## Classifying with a model instead of the heuristics

The built-in parsing is deliberately literal and gives up on anything odd -
`Part 1`/`Pt.1` instead of `SxxEyy`, anime absolute numbering, foreign-language
titles, box sets, or a show whose spelling doesn't match the library's folder.
For those, let a model do the classification and keep the script as the (safe)
executor. Use a **Haiku subagent** - it is cheap, and this is a
pattern-matching task over a file listing, not a reasoning-heavy one.

```bash
# 1. Get the evidence: every entry with its full file tree and sizes
ssh ragnar "bash /tmp/sort-completed-downloads.sh --plan-json" > /tmp/plan.json

# 2. Have the model turn that into an explicit move list (see shape below),
#    then push it and dry-run
scp /tmp/decisions.json ragnar:/tmp/
ssh ragnar "bash /tmp/sort-completed-downloads.sh --apply-plan /tmp/decisions.json --dry-run"
ssh ragnar "bash /tmp/sort-completed-downloads.sh --apply-plan /tmp/decisions.json"
```

Decisions file shape (absolute paths):

```json
{"moves":   [{"src": "/mnt/tank/common/.../file.mkv", "dest": "/mnt/tank/media/Movies/1080p/A/file.mkv"}],
 "cleanup": ["/mnt/tank/common/transmission/downloads/<entry dir>"],
 "skip":    [{"name": "<entry>", "reason": "still downloading"}]}
```

When prompting the classifier, give it the library conventions above and tell
it to: skip any entry with `"complete": false`; ignore sample/featurette files
(much smaller than the main video); and put anything it is *not* confident
about into `skip` rather than guessing a destination.

`--apply-plan` validates every line before acting: it refuses a `dest` outside
`Movies/`/`TV Shows/`, refuses `cleanup` outside `downloads/`, skips a `src`
that has vanished, never overwrites an existing `dest`, and won't remove a
directory that still holds video files. A wrong plan gets rejected, not
executed - so the model's output never needs to be trusted blindly.

## Verify TV numbering against TheTVDB when it might be off

`--apply-plan` checks that a plan is *safe*, not that its numbering is
*correct*. Plex matches TV against TheTVDB's **official (aired) order**, so a
file labelled with the wrong `SxxEyy` gets the wrong title, art and watched
state, and nothing complains. Whenever there's reason to doubt the
release's numbering, check it against TVDB before applying the plan.

**When to check** (any one of these is enough):
- the release uses its own scheme - "Book 2", "Volume", "Part 1 of 3",
  `S02 E08` with a space, `1x08`, absolute or anime numbering, DVD order
- shorts, webisodes, OVAs, recaps or "specials" mixed into a pack (these
  belong in Season 0 - see below)
- folder numbering and file numbering disagree (Korra's `Book 2a`/`2b` folders
  hold the Republic City Hustle shorts and Season 2 respectively)
- gaps, duplicates, or a season episode count that looks wrong for the show
- double episodes (`S01E01-E02`), or a two-parter that might be one TVDB entry
- a title that's ambiguous, a remake or reboot, or shares its name with another show

**How to check:**
1. Fetch the official order with WebFetch:
   `https://thetvdb.com/series/<slug>/allseasons/official` for the main
   seasons, and `https://thetvdb.com/series/<slug>/seasons/official/0` for
   specials. Ask for one `SxxEyy Title` line per episode. If you don't know
   the slug, a quick web search for "thetvdb <show>" will give it.
2. **Diff it in code, not by eye.** Save the TVDB list to the scratchpad,
   pull `SxxEyy` and the title out of each release filename, and compare them.
   Report the counts per season and every mismatch. Expect cosmetic
   differences ("Part 1 of 2" vs "(1)", a trailing "…"), so normalise those
   first and only look closely at what's left.
3. Build the plan's `dest`s from the **TVDB** numbering, not the release's.
   Anything that maps to no TVDB entry goes to `skip`, not a guess.

**Specials** go in `TV Shows/<tier>/<Show>/Season 0/<Show> S00Eyy.<ext>`, with
`yy` from TVDB's season-0 list. That follows the library's `Season N` style.
The library had no specials folders before 2026-10-06; *The Legend of Korra*
`Season 0` (Republic City Hustle = S00E01-E03) is the first.

Mention what you checked against in the report (e.g. "52/52 titles match
TVDB's official order; shorts are S00E01-E03").

## What it does

- **Classifies** an entry as TV if any contained (fully-downloaded) video
  filename matches `SxxEyy`; otherwise movie.
- **Neither movie nor TV** (the rare non-media download — an ISO, album,
  ebook, game): flagged and left in place, never filed into `Movies/`. This
  covers both a folder with no video files in it and a bare top-level file
  whose extension isn't a video one.
- **Skips entirely** any entry that still contains `*.part` files anywhere
  inside it, even if some of its episodes are individually complete -
  a season pack that's 65% done should not be half-migrated.
- **Movie:** picks the *largest* video file in the entry as the film
  (samples/ad clips are always much smaller); resolution tag is read from
  either the release folder name or the video filename, since uploaders
  sometimes rename the file to something generic; letter bucket from the
  cleaned filename.
- **TV:** every video file matching `SxxEyy` in the entry is a candidate
  episode (handles season packs); show name is whatever precedes the
  `SxxEyy` token with dots/underscores turned to spaces.
- Moves subtitles alongside their movie; sets `tim:smb-users` ownership and
  `g+rwX` on everything moved; removes the emptied source folder.
- **Never overwrites** an existing destination file - logs a conflict and
  leaves both copies in place for manual resolution.
- **Flags rather than guesses** when it can't confidently parse a
  show/season/episode from a TV filename.

## Judgment calls / things to check after running

- **If a dry run files a multi-episode pack as a MOVIE, stop.** The built-in
  TV regex needs `SxxEyy` with no gap. `S02 E08` with a space, and Book or
  Part naming, fall through to the movie path: it would move one episode
  into `Movies/` and pile every other episode's subtitles beside it. Switch
  to `--apply-plan` and the TVDB check above.
- **A box set with only some folders on disk** is usually a partial selection
  in Transmission (the operator ticked only some parts), not a stalled
  download. Ask rather than wait. To confirm nothing is still being written,
  check that the entry's `du -sb` stays the same over about 30 seconds.
- `pgrep -f sort-completed` run inside the same `ssh` command matches that
  command's own line, so it reports a run that isn't there. Use
  `pgrep -af ... | grep -v pgrep` or check the pid printed by `--detach`.
- Read the final summary's **Conflicts** and **Flagged** sections - nothing
  in those was moved.
- Verify the run: destination files exist with `tim:smb-users` ownership,
  and `downloads/` is empty apart from stray `.DS_Store` / still-seeding
  entries — e.g.
  `ssh ragnar "ls -la '/mnt/tank/media/Movies/1080p/<letter>/' ; ls -la /mnt/tank/common/transmission/downloads/"`.
- The script deliberately does **not** touch Transmission (stopping or
  removing torrents whose data just moved) - that was a deliberate choice
  on 2026-08-04 to leave seeding torrents alone rather than cut ratios
  short. Torrents whose files moved will show read errors in Transmission;
  harmless, clean up in the UI when convenient. Revisit this default if it
  becomes annoying enough to want `transmission-remote --remove` wired in.
- TV show-name parsing is best-effort (dots/underscores → spaces, article
  not stripped). If a newly-downloaded show's cleaned name doesn't exactly
  match an existing show folder's spelling/punctuation, it'll create a
  second folder for the same show under its own resolution tier rather than
  merging - check `TV Shows/*/` for near-duplicate show names after a TV run.
