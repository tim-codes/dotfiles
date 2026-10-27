#!/bin/bash
# Tests for the folder-trust step in scripts/claude-kickoff: --check-trust <cwd>
# (read-only), --no-trust (check only, refuse with exit 3), and the default --trust
# (record the cwd as trusted before a launch). Runs under a fake $HOME with a temp
# config dir and a stub `claude` that only records that it was started; nothing real
# launches and no live .claude.json is read. Cases: trusted path -> 0, untrusted -> 3,
# path absent from `projects` -> 3, invalid JSON or no file -> 2, a symlinked path
# resolves to its real path, --no-trust refuses a launch (exit 3, stub never run),
# --no-trust-check skips everything, and a refusal under --dry-run too (the herder's
# view). Seeding: a fresh dir gets its entry, a merge keeps every other key and
# project, an already-trusted cwd is `trust: ok` with no backup, invalid JSON is exit
# 2 with the file untouched, a dry run only says `would-record`, a missing file is
# created, a launch records before the stub starts, and the flags' precedence.
# Usage: bash tests/claude-kickoff-trust.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KICK="$SRC_REPO/scripts/claude-kickoff"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAKE="$(cd "$T" && pwd -P)/home"; BIN="$T/bin"; STARTED="$T/started"
CFG="$FAKE/.claude-exxo-personal"
W="$FAKE/work"
mkdir -p "$CFG" "$BIN" "$W/trusted" "$W/untrusted" "$W/falsy" "$W/absent"
ln -s "$W/trusted" "$W/link"
for tool in yq jq; do
    real="$(command -v "$tool" || true)"
    [ -n "$real" ] && ln -s "$real" "$BIN/$tool"
done
cat >"$BIN/claude" <<EOF2
#!/bin/bash
echo started >"$STARTED"
EOF2
chmod +x "$BIN/claude"
export CLAUDE_KICKOFF_CONTEXTS="$SRC_REPO/src/.config/claude-kickoff/contexts.toml"
unset CLAUDE_KICKOFF_NO_TRUST_CHECK

cat >"$CFG/.claude.json" <<EOF2
{"projects": {
  "$W/trusted":   {"hasTrustDialogAccepted": true},
  "$W/untrusted": {"hasTrustDialogAccepted": false},
  "$W/falsy":     {"allowedTools": []}
}}
EOF2
cat >"$T/k.md" <<EOF2
cwd: $W/trusted
context: exxo-personal
model: opus
effort: high
---
Do the thing.
EOF2
sed "s#^cwd: .*#cwd: $W/untrusted#" "$T/k.md" >"$T/k-untrusted.md"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

# kick <args...>: sets rc, out (stdout), err (stderr).
kick() {
    rm -f "$STARTED"
    out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" "$KICK" "$@" 2>"$T/err"); rc=$?
    err=$(cat "$T/err")
}
yes_if() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
expect() { # expect <desc> <rc> <stdout substring|-> <stderr substring|-> <args...>
    local d="$1" want="$2" so="$3" se="$4"; shift 4
    kick "$@"
    if [ "$rc" -ne "$want" ]; then bad "$d: exit $rc, wanted $want (out: $out; err: $err)"; return; fi
    if [ "$so" != - ] && ! printf '%s\n' "$out" | grep -qF -- "$so"; then bad "$d: stdout lacks '$so': $out"; return; fi
    if [ "$se" != - ] && ! printf '%s\n' "$err" | grep -qF -- "$se"; then bad "$d: stderr lacks '$se': $err"; return; fi
    ok "$d (exit $want)"
}

HINT="open the folder once in exxo-personal and accept the trust dialog, or start the member attended"
CT=(--check-trust)
expect "check: trusted path" 0 "trust: ok $W/trusted in exxo-personal" - "${CT[@]}" "$W/trusted" --account exxo-personal
expect "check: flag false" 3 - "trust: missing $W/untrusted in exxo-personal" "${CT[@]}" "$W/untrusted" --account exxo-personal
expect "check: entry without the flag" 3 - "trust: missing $W/falsy in exxo-personal" "${CT[@]}" "$W/falsy" --account exxo-personal
expect "check: path absent from projects" 3 - "trust: missing $W/absent in exxo-personal" "${CT[@]}" "$W/absent" --account exxo-personal
expect "check: refusal says what to do" 3 - "$HINT" "${CT[@]}" "$W/absent" --account exxo-personal
expect "check: symlink resolves to the real path" 0 "trust: ok $W/trusted in exxo-personal" - "${CT[@]}" "$W/link" --account exxo-personal
# shellcheck disable=SC2088 # the literal ~ is the point: the launcher expands it
expect "check: ~ expands against HOME" 0 "trust: ok $W/trusted in exxo-personal" - "${CT[@]}" "~/work/trusted" --account exxo-personal
expect "check: needs --account" 2 - "needs --account" "${CT[@]}" "$W/trusted"

# a different context has its own trust file
mkdir -p "$FAKE/.claude-exxo-openrouter"
expect "check: another context, no file" 2 - "missing or unreadable" "${CT[@]}" "$W/trusted" --account exxo-openrouter

# the live-file shape: no `projects` key at all
printf '{}\n' >"$CFG/.claude.json"
expect "check: no projects map" 3 - "trust: missing" "${CT[@]}" "$W/trusted" --account exxo-personal
printf '{not json\n' >"$CFG/.claude.json"
expect "check: invalid JSON" 2 - "not a valid JSON object" "${CT[@]}" "$W/trusted" --account exxo-personal
printf '[1, 2]\n' >"$CFG/.claude.json"
expect "check: JSON but not an object" 2 - "not a valid JSON object" "${CT[@]}" "$W/trusted" --account exxo-personal
rm -f "$CFG/.claude.json"
expect "check: no file" 2 - "missing or unreadable" "${CT[@]}" "$W/trusted" --account exxo-personal

# launches: restore the trust file, then exercise the check-only mode (--no-trust)
cat >"$CFG/.claude.json" <<EOF2
{"projects": {"$W/trusted": {"hasTrustDialogAccepted": true}}}
EOF2
before=$(shasum "$CFG/.claude.json")
NT=(--no-trust)
expect "launch: trusted cwd launches" 0 - - "$T/k.md"
yes_if "launch: trusted cwd ran the stub" test -e "$STARTED"
expect "launch: --no-trust refuses an untrusted cwd" 3 - "trust: missing $W/untrusted in exxo-personal" "$T/k-untrusted.md" "${NT[@]}"
yes_if "launch: refusal never started claude" test ! -e "$STARTED"
expect "launch: refusal says what to do" 3 - "$HINT" "$T/k-untrusted.md" "${NT[@]}"
expect "launch: --no-trust-check skips it" 0 - - "$T/k-untrusted.md" --no-trust-check
yes_if "launch: --no-trust-check ran the stub" test -e "$STARTED"
expect "launch: --no-trust-check beats --trust" 0 "trust:" - "$T/k-untrusted.md" --no-trust-check --trust --dry-run
rm -f "$STARTED"
out=$(CLAUDE_KICKOFF_NO_TRUST_CHECK=1 HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" "$KICK" "$T/k-untrusted.md" 2>&1); rc=$?
yes_if "launch: CLAUDE_KICKOFF_NO_TRUST_CHECK=1 skips it (exit $rc)" test "$rc" -eq 0 -a -e "$STARTED"
expect "launch: --no-trust and no trust file is exit 2" 2 - "missing or unreadable" "$T/k.md" --account exxo-openrouter "${NT[@]}"

# --dry-run is the herder's view: --no-trust refuses it, and nothing launches
expect "dry-run: --no-trust refuses an untrusted cwd" 3 - "trust: missing $W/untrusted in exxo-personal" "$T/k-untrusted.md" --dry-run "${NT[@]}"
expect "dry-run: trusted cwd reports trust: ok" 0 "trust: ok $W/trusted in exxo-personal" - "$T/k.md" --dry-run
expect "dry-run: --no-trust-check reports skipped" 0 "trust: skipped" - "$T/k-untrusted.md" --dry-run --no-trust-check
expect "dry-run: untrusted cwd would be recorded (default)" 0 "trust: would-record $W/untrusted in exxo-personal" - "$T/k-untrusted.md" --dry-run
expect "dry-run: --no-trust after --trust wins" 3 - "trust: missing" "$T/k-untrusted.md" --dry-run --trust --no-trust
expect "dry-run: --trust after --no-trust wins" 0 "trust: would-record" - "$T/k-untrusted.md" --dry-run --no-trust --trust
expect "check: --check-trust stays read-only with --trust" 3 - "trust: missing $W/untrusted" --check-trust "$W/untrusted" --account exxo-personal --trust

# nothing above wrote the trust file (a dry run and a refusal are side-effect free)
after=$(shasum "$CFG/.claude.json")
yes_if "the trust file is untouched" test "$before" = "$after"
yes_if "no backup or temp file appeared" test -z "$(find "$CFG" -maxdepth 1 -name '.claude.json.*')"

# --- seeding (the default --trust) ----------------------------------------------
baks() { find "$CFG" -maxdepth 1 -name '.claude.json.bak-*' | wc -l | tr -d ' '; }
tmps() { find "$CFG" -maxdepth 1 -name '.claude.json.tmp.*' | wc -l | tr -d ' '; }
# shellcheck disable=SC2329 # run through yes_if
trusted_in() { jq -e --arg p "$1" '.projects[$p].hasTrustDialogAccepted == true' "$CFG/.claude.json" >/dev/null 2>&1; }

# a fresh dir in a file that has other keys and projects (2-space indent, as Claude writes)
cat >"$CFG/.claude.json" <<EOF2
{
  "numStartups": 42,
  "theme": "dark",
  "oauthAccount": {
    "emailAddress": "someone@example.invalid"
  },
  "projects": {
    "$W/trusted": {
      "hasTrustDialogAccepted": true,
      "allowedTools": [
        "Bash(ls:*)"
      ]
    },
    "$W/falsy": {
      "allowedTools": []
    }
  }
}
EOF2
cp "$CFG/.claude.json" "$T/orig.json"
expect "seed: untrusted cwd launches" 0 "trust: recorded $W/untrusted in exxo-personal" - "$T/k-untrusted.md"
yes_if "seed: the stub started after recording" test -e "$STARTED"
yes_if "seed: the entry is now trusted" trusted_in "$W/untrusted"
yes_if "seed: other top-level keys unchanged" test "$(jq -cS 'del(.projects)' "$T/orig.json")" = "$(jq -cS 'del(.projects)' "$CFG/.claude.json")"
yes_if "seed: other projects unchanged" test "$(jq -cS --arg p "$W/untrusted" '.projects | del(.[$p])' "$CFG/.claude.json")" = "$(jq -cS '.projects' "$T/orig.json")"
yes_if "seed: the diff only adds lines (byte-for-byte elsewhere)" test -z "$(diff "$T/orig.json" "$CFG/.claude.json" | grep '^<')"
yes_if "seed: exactly one backup, equal to the original" test "$(baks)" = 1 -a "$(cat "$CFG"/.claude.json.bak-*)" = "$(cat "$T/orig.json")"
yes_if "seed: no temp file left behind" test "$(tmps)" = 0
yes_if "seed: mode preserved" test "$(stat -f %Lp "$CFG/.claude.json" 2>/dev/null || stat -c %a "$CFG/.claude.json")" = "$(stat -f %Lp "$T/orig.json" 2>/dev/null || stat -c %a "$T/orig.json")"

# an entry that exists without the flag gets it merged in, keeping its other keys
rm -f "$CFG"/.claude.json.bak-*
cp "$CFG/.claude.json" "$T/orig2.json"
expect "seed: entry without the flag" 0 "trust: recorded $W/falsy in exxo-personal" - "$T/k.md" --account exxo-personal --cwd "$W/falsy" --resume s1
yes_if "seed: flag merged, allowedTools kept" test "$(jq -c --arg p "$W/falsy" '.projects[$p]' "$CFG/.claude.json")" = '{"allowedTools":[],"hasTrustDialogAccepted":true}'
yes_if "seed: one new backup" test "$(baks)" = 1

# already trusted: ok, no write, no backup
rm -f "$CFG"/.claude.json.bak-*
before=$(shasum "$CFG/.claude.json")
expect "seed: already trusted is trust: ok" 0 "trust: ok $W/untrusted in exxo-personal" - "$T/k-untrusted.md"
yes_if "seed: already trusted wrote nothing" test "$before" = "$(shasum "$CFG/.claude.json")" -a "$(baks)" = 0
expect "seed: already trusted prints no 'recorded'" 0 - - "$T/k-untrusted.md"
yes_if "seed: ... and no recorded line" test -z "$(printf '%s' "$out" | grep recorded)"

# a file with no projects map at all
printf '{"numStartups": 1}\n' >"$CFG/.claude.json"
expect "seed: file without a projects map" 0 "trust: recorded $W/untrusted in exxo-personal" - "$T/k-untrusted.md"
yes_if "seed: projects map created, other key kept" test "$(jq -c . "$CFG/.claude.json")" = "{\"numStartups\":1,\"projects\":{\"$W/untrusted\":{\"hasTrustDialogAccepted\":true}}}"

# a symlinked cwd records the real path
rm -f "$CFG"/.claude.json.bak-*
rm -f "$CFG/.claude.json"
mkdir -p "$W/linktarget"; ln -sfn "$W/linktarget" "$W/link2"
sed "s#^cwd: .*#cwd: $W/link2#" "$T/k.md" >"$T/k-link2.md"
expect "seed: missing file is created, the real path recorded" 0 "trust: recorded $W/linktarget in exxo-personal" - "$T/k-link2.md"
yes_if "seed: created file is minimal" test "$(jq -c . "$CFG/.claude.json")" = "{\"projects\":{\"$W/linktarget\":{\"hasTrustDialogAccepted\":true}}}"
yes_if "seed: no backup for a file that did not exist" test "$(baks)" = 0 -a "$(tmps)" = 0

# invalid JSON: exit 2, the file untouched, no backup, nothing launched
rm -f "$CFG"/.claude.json.bak-*
printf '{not json\n' >"$CFG/.claude.json"
cp "$CFG/.claude.json" "$T/bad.json"
expect "seed: invalid JSON is exit 2" 2 - "not a valid JSON object" "$T/k-untrusted.md"
yes_if "seed: invalid JSON left untouched, no backup, stub not run" test "$(cat "$CFG/.claude.json")" = "$(cat "$T/bad.json")" -a "$(baks)" = 0 -a "$(tmps)" = 0 -a ! -e "$STARTED"
expect "seed: invalid JSON is exit 2 under --dry-run too" 2 - "not a valid JSON object" "$T/k-untrusted.md" --dry-run
printf '{"projects": []}\n' >"$CFG/.claude.json"
cp "$CFG/.claude.json" "$T/bad.json"
expect "seed: projects that is not an object is exit 2" 2 - "not an object" "$T/k-untrusted.md"
yes_if "seed: ... and the file is untouched" test "$(cat "$CFG/.claude.json")" = "$(cat "$T/bad.json")" -a "$(baks)" = 0

# dry run: would-record, exit 0, the file untouched, no backup, nothing launched
rm -f "$CFG"/.claude.json.bak-*
cp "$T/orig.json" "$CFG/.claude.json"
expect "seed: dry-run says would-record" 0 "trust: would-record $W/untrusted in exxo-personal" - "$T/k-untrusted.md" --dry-run
yes_if "seed: dry-run left the file untouched, no backup" test "$(cat "$CFG/.claude.json")" = "$(cat "$T/orig.json")" -a "$(baks)" = 0 -a "$(tmps)" = 0 -a ! -e "$STARTED"
rm -f "$CFG/.claude.json"
expect "seed: dry-run with no file says would-record" 0 "trust: would-record $W/untrusted in exxo-personal" - "$T/k-untrusted.md" --dry-run
yes_if "seed: dry-run did not create the file" test ! -e "$CFG/.claude.json"

# --no-trust: refusal unchanged, nothing written
rm -f "$CFG"/.claude.json.bak-*
cp "$T/orig.json" "$CFG/.claude.json"
expect "seed: --no-trust still refuses (exit 3)" 3 - "trust: missing $W/untrusted in exxo-personal" "$T/k-untrusted.md" --no-trust
yes_if "seed: --no-trust wrote nothing" test "$(cat "$CFG/.claude.json")" = "$(cat "$T/orig.json")" -a "$(baks)" = 0 -a ! -e "$STARTED"
expect "seed: --no-trust-check records nothing" 0 "trust: skipped" - "$T/k-untrusted.md" --dry-run --no-trust-check
yes_if "seed: ... the file is untouched" test "$(cat "$CFG/.claude.json")" = "$(cat "$T/orig.json")"
rm -f "$STARTED"
out=$(CLAUDE_KICKOFF_NO_TRUST_CHECK=1 HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" "$KICK" "$T/k-untrusted.md" 2>&1); rc=$?
yes_if "seed: the env skip records nothing either" test "$rc" -eq 0 -a -e "$STARTED" -a "$(cat "$CFG/.claude.json")" = "$(cat "$T/orig.json")"

exit "$fail"
