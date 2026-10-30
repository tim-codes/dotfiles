#!/bin/bash
# Exercise claude-sync's retirement of a context-level settings.local.json
# against a throwaway repo copy and a fake $HOME — never the real contexts.
# Checks --diff reports rule COUNTS only (never values) and changes nothing,
# and that apply backs the file up, removes it and prints the promote hint.
# Usage: bash tests/claude-sync-local-settings.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal reserve exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }

SECRET_RULE='WebFetch(domain:sentinel-do-not-print.example)'
printf '{"permissions":{"allow":["%s","Bash(x:*)"],"deny":["Bash(y:*)"]},"other":"sentinel-other"}\n' \
    "$SECRET_RULE" > "$FAKE/.claude-exxo/settings.local.json"
printf '{"permissions":{"allow":["WebSearch"]}}\n' > "$FAKE/.claude-personal/settings.local.json"
cp "$FAKE/.claude-exxo/settings.local.json" "$T/exxo.orig"

out="$(sync --diff 2>&1)"
check "diff: exxo counts line" \
    grep -qF 'settings.local.json: present (2 allow / 1 deny / 0 ask rules) — would be retired' <<<"$out"
check "diff: personal counts line" \
    grep -qF 'settings.local.json: present (1 allow / 0 deny / 0 ask rules) — would be retired' <<<"$out"
check "diff: no rule values or other keys printed" \
    bash -c '! grep -qE "sentinel|Bash\(x|Bash\(y" <<<"$1"' _ "$out"
check "diff: reserve (no file) reports nothing" \
    bash -c '[ "$(grep -c "settings.local.json: present" <<<"$1")" = 2 ]' _ "$out"
check "diff changed nothing" cmp -s "$FAKE/.claude-exxo/settings.local.json" "$T/exxo.orig"

sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }
for c in personal exxo; do
    check "$c settings.local.json removed" test ! -e "$FAKE/.claude-$c/settings.local.json"
    check "$c backup written" bash -c 'ls "$1"/settings.local.json.bak-* >/dev/null' _ "$FAKE/.claude-$c"
done
check "exxo backup is identical to the original" \
    bash -c 'cmp -s "$1" "$2"/settings.local.json.bak-*' _ "$T/exxo.orig" "$FAKE/.claude-exxo"
check "apply prints the promote hint" \
    grep -q 'promote anything worth keeping into settings.shared.json / settings.exxo.json' "$T/apply.log"
check "apply output prints no rule values" bash -c '! grep -q sentinel "$1"' _ "$T/apply.log"
check "contexts without the file got no backup" \
    bash -c '! ls "$1"/settings.local.json.bak-* >/dev/null 2>&1' _ "$FAKE/.claude-reserve"

sync >"$T/again.log" 2>&1
check "re-run is quiet about settings.local.json" bash -c '! grep -q "settings.local.json" "$1"' _ "$T/again.log"

exit "$fail"
