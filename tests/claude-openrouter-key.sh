#!/bin/bash
# Tests for scripts/claude-openrouter-key, the apiKeyHelper of the
# exxo-openrouter context. Fake $HOME and a placeholder key only; the real
# ~/keys is never touched.
# Usage: bash tests/claude-openrouter-key.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$SRC_REPO/scripts/claude-openrouter-key"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
KEY=sk-or-TEST-PLACEHOLDER
KF="$HOME/keys/openrouter.key"
LOG="$HOME/.local/state/claude-openrouter/keyhelper.jsonl"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

# run [content-printf-format] [mode]: fresh HOME; sets OUT, ERR, RC.
run() {
  rm -rf "$HOME"; mkdir -p "$HOME/keys"; chmod 700 "$HOME/keys"
  if [ $# -ge 1 ]; then printf "$1" >"$KF"; chmod "${2:-600}" "$KF"; fi
  OUT="$("$HELPER" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
}
fails_quietly() { # name
  if [ "$RC" -ne 0 ] && [ -z "$OUT" ]; then ok "$1: non-zero, empty stdout"; else bad "$1: rc=$RC out='$OUT'"; fi
  case "$ERR$OUT" in *"$KEY"*) bad "$1: key leaked";; *) ok "$1: key not leaked";; esac
}

run "$KEY" 600
[ "$RC" -eq 0 ] && [ "$OUT" = "$KEY" ] && [ -z "$ERR" ] && ok "a: key printed, stderr empty" || bad "a: rc=$RC out='$OUT' err='$ERR'"
[ "$("$HELPER" 2>/dev/null | od -c | head -1 | tr -d ' ')" = "$(printf '%s\n' "$KEY" | od -c | head -1 | tr -d ' ')" ] && ok "a: exactly key + newline" || bad "a: byte-exact output"
[ ! -e "$LOG" ] && ok "a: success not logged" || bad "a: success logged"

run
fails_quietly b
case "$ERR" in *"$KF"*) ok "b: stderr names path";; *) bad "b: stderr='$ERR'";; esac
grep -q '"reason": *"missing"' "$LOG" && ok "b: logged missing" || bad "b: log"

run "$KEY\n" 644
fails_quietly c
case "$ERR" in *mode*) ok "c: stderr mentions mode";; *) bad "c: stderr='$ERR'";; esac
grep -q '"reason": *"mode"' "$LOG" && ok "c: logged mode" || bad "c: log"
run "$KEY\n" 640; fails_quietly c640

run '' 600
fails_quietly d
grep -q '"reason": *"empty"' "$LOG" && ok "d: logged empty" || bad "d: log"
run ' \n\t\n' 600; fails_quietly d-ws

run "  $KEY  \n\n\n" 600
[ "$RC" -eq 0 ] && [ "$OUT" = "$KEY" ] && ok "e: whitespace trimmed" || bad "e: out='$OUT'"

# not a regular file
run; mkdir "$KF"; chmod 600 "$KF"
OUT="$("$HELPER" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
fails_quietly regular

# read error (mode 600 but unreadable is impossible at 600 for owner; use 000 -> mode reason)
run "$KEY\n" 000
fails_quietly unreadable

# f/O10: failure log has ts + reason only, never key, length or prefix
run "$KEY\n" 644
if [ "$(wc -l <"$LOG")" -eq 1 ] \
   && python3 - "$LOG" <<'PY'
import json, sys
r = json.loads(open(sys.argv[1]).read())
assert set(r) == {"ts", "reason"}, r
assert r["reason"] == "mode"
assert "sk-or" not in json.dumps(r)
PY
then ok "failure_logged_without_key_or_length: shape"; else bad "failure_logged_without_key_or_length: shape"; fi
[ "$(stat -f %Lp "$LOG" 2>/dev/null || stat -c %a "$LOG")" = 600 ] && ok "log mode 600" || bad "log mode"
[ "$(stat -f %Lp "$(dirname "$LOG")" 2>/dev/null || stat -c %a "$(dirname "$LOG")")" = 700 ] && ok "log dir mode 700" || bad "log dir mode"

exit $fail
