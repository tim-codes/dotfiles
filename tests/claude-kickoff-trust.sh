#!/bin/bash
# Tests for the folder-trust check in scripts/claude-kickoff: --check-trust <cwd>
# and the default check on a launch. Runs under a fake $HOME with a temp config dir
# and a stub `claude` that only records that it was started; nothing real launches
# and no live .claude.json is read. Cases: trusted path -> 0, untrusted -> 3, path
# absent from `projects` -> 3, invalid JSON or no file -> 2, a symlinked path
# resolves to its real path, a launch is refused (exit 3, stub never run) unless
# --no-trust-check, and a refusal under --dry-run too (the herder's view).
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

# launches: restore the trust file, then exercise the default check
cat >"$CFG/.claude.json" <<EOF2
{"projects": {"$W/trusted": {"hasTrustDialogAccepted": true}}}
EOF2
before=$(shasum "$CFG/.claude.json")
expect "launch: trusted cwd launches" 0 - - "$T/k.md"
yes_if "launch: trusted cwd ran the stub" test -e "$STARTED"
expect "launch: untrusted cwd is refused" 3 - "trust: missing $W/untrusted in exxo-personal" "$T/k-untrusted.md"
yes_if "launch: refusal never started claude" test ! -e "$STARTED"
expect "launch: refusal says what to do" 3 - "$HINT" "$T/k-untrusted.md"
expect "launch: --no-trust-check skips it" 0 - - "$T/k-untrusted.md" --no-trust-check
yes_if "launch: --no-trust-check ran the stub" test -e "$STARTED"
rm -f "$STARTED"
out=$(CLAUDE_KICKOFF_NO_TRUST_CHECK=1 HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" "$KICK" "$T/k-untrusted.md" 2>&1); rc=$?
yes_if "launch: CLAUDE_KICKOFF_NO_TRUST_CHECK=1 skips it (exit $rc)" test "$rc" -eq 0 -a -e "$STARTED"
expect "launch: no trust file refuses (exit 2)" 2 - "missing or unreadable" "$T/k.md" --account exxo-openrouter

# --dry-run is the herder's view: it must see the refusal, and nothing launches
expect "dry-run: untrusted cwd is refused" 3 - "trust: missing $W/untrusted in exxo-personal" "$T/k-untrusted.md" --dry-run
expect "dry-run: trusted cwd reports trust: ok" 0 "trust: ok $W/trusted in exxo-personal" - "$T/k.md" --dry-run
expect "dry-run: --no-trust-check reports skipped" 0 "trust: skipped" - "$T/k-untrusted.md" --dry-run --no-trust-check

# read-only: the trust file was never written
after=$(shasum "$CFG/.claude.json")
yes_if "the trust file is untouched" test "$before" = "$after"

exit "$fail"
