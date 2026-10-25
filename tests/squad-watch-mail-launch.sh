#!/bin/bash
# The mail watcher's launchd wrapper (src/bin/squad-watch-mail-launch), run
# against stub `security` and `squad` commands on PATH: no Keychain, no real
# squad. Checks: the token reaches squad as OP_SERVICE_ACCOUNT_TOKEN, squad
# is run as `watch mail`, the token is never printed, and a missing item
# exits 78 with one line and starts nothing.
# Usage: bash tests/squad-watch-mail-launch.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAP="$SRC_REPO/src/bin/squad-watch-mail-launch"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# A stub `security` that answers only the one lookup, from $FAKE_TOKEN.
cat > "$T/bin/security" <<'STUB'
#!/bin/bash
[ "$*" = "find-generic-password -s tim-squad-op-sa -w" ] || exit 44
[ -n "${FAKE_TOKEN:-}" ] || exit 44
printf '%s\n' "$FAKE_TOKEN"
STUB
# A stub `squad` that records its argv and whether the token arrived.
cat > "$T/bin/squad" <<'STUB'
#!/bin/bash
{ echo "argv: $*"; [ "${OP_SERVICE_ACCOUNT_TOKEN:-}" = "fake-sa-token" ] && echo "token: yes"; } > "$SQUAD_OUT"
STUB
chmod +x "$T/bin/security" "$T/bin/squad"

export SQUAD_OUT="$T/out"
out="$(PATH="$T/bin:/usr/bin:/bin" FAKE_TOKEN=fake-sa-token bash "$WRAP" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "starts when the item exists" || bad "starts when the item exists (rc=$rc)"
grep -qx "argv: watch mail" "$T/out" && ok "runs squad watch mail" || bad "runs squad watch mail"
grep -qx "token: yes" "$T/out" && ok "token reaches squad in OP_SERVICE_ACCOUNT_TOKEN" || bad "token reaches squad"
case "$out" in *fake-sa-token*) bad "token printed" ;; *) ok "token never printed" ;; esac

rm -f "$T/out"
out="$(PATH="$T/bin:/usr/bin:/bin" FAKE_TOKEN= bash "$WRAP" 2>&1)"; rc=$?
[ "$rc" = 78 ] && ok "exits 78 without the item" || bad "exits 78 without the item (rc=$rc)"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && ok "one error line" || bad "one error line: $out"
[ ! -e "$T/out" ] && ok "squad not started" || bad "squad started without a token"

exit "$fail"
