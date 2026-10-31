#!/bin/bash
# Tests for scripts/npmrc-render. Fake $HOME, a stub `op` on PATH and a fake
# token only; the real ~/.npmrc and 1Password are never touched.
# Usage: bash tests/npmrc-render.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SRC_REPO/scripts/npmrc-render"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME" "$T/bin"
TOKEN=ghp_FAKE_TOKEN_for_tests_only
RC_FILE="$HOME/.npmrc"
WANT="$(printf '@exxo-labs:registry=https://npm.pkg.github.com\n//npm.pkg.github.com/:_authToken=%s\n' "$TOKEN")"

# Stub op: logs argv, prints $FAKE_TOKEN (exit 1 when empty). No agent-run on
# PATH, so the op path is the one exercised.
cat >"$T/bin/op" <<'STUB'
#!/bin/bash
echo "$*" >>"$STUB_LOG"
[ -n "${FAKE_TOKEN:-}" ] || exit 1
printf '%s\n' "$FAKE_TOKEN"
STUB
chmod +x "$T/bin/op"
export STUB_LOG="$T/op.log"
export PATH="$T/bin:/usr/bin:/bin"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# a: fresh render
FAKE_TOKEN=$TOKEN OUT="$(FAKE_TOKEN=$TOKEN bash "$SCRIPT" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "a: exit 0" || bad "a: rc=$rc"
[ "$(cat "$RC_FILE")" = "$WANT" ] && ok "a: exact content" || bad "a: content"
[ "$(mode "$RC_FILE")" = 600 ] && ok "a: mode 600" || bad "a: mode $(mode "$RC_FILE")"
case "$OUT" in *"$TOKEN"*) bad "a: token printed";; *) ok "a: token not printed";; esac
grep -q 'Exxo Engineering/\[EXXO\] github npm read PAT' "$STUB_LOG" && ok "a: read the named item" || bad "a: op argv: $(cat "$STUB_LOG")"

# b: idempotent re-run leaves the file untouched (inode and mtime)
touch -t 202001010000 "$RC_FILE"
before="$(ls -li "$RC_FILE" | awk '{print $1}') $(stat -f %m "$RC_FILE" 2>/dev/null || stat -c %Y "$RC_FILE")"
OUT="$(FAKE_TOKEN=$TOKEN bash "$SCRIPT" 2>&1)"
after="$(ls -li "$RC_FILE" | awk '{print $1}') $(stat -f %m "$RC_FILE" 2>/dev/null || stat -c %Y "$RC_FILE")"
[ "$before" = "$after" ] && ok "b: inode and mtime unchanged" || bad "b: $before -> $after"
case "$OUT" in *"$TOKEN"*) bad "b: token printed";; *) ok "b: token not printed";; esac

# c: loose mode is tightened without rewriting content
chmod 644 "$RC_FILE"; FAKE_TOKEN=$TOKEN bash "$SCRIPT" >/dev/null 2>&1
[ "$(mode "$RC_FILE")" = 600 ] && ok "c: mode repaired" || bad "c: mode"

# d: rotated token is rewritten
FAKE_TOKEN=ghp_FAKE_ROTATED bash "$SCRIPT" >/dev/null 2>&1
grep -q 'ghp_FAKE_ROTATED' "$RC_FILE" && [ "$(wc -l <"$RC_FILE" | tr -d ' ')" = 2 ] && ok "d: rotated token written, 2 lines" || bad "d: rotation"

# e: op failure leaves the file alone and exits non-zero
cp "$RC_FILE" "$T/snap"
FAKE_TOKEN= bash "$SCRIPT" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$RC_FILE" "$T/snap" && ok "e: failure keeps file, non-zero" || bad "e: rc=$rc"

exit $fail
