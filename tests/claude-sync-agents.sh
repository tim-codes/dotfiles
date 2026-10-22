#!/bin/bash
# Exercise claude-sync's agents/ delivery path against a throwaway repo copy
# and a fake $HOME — never the real contexts. claude-sync derives REPO_DIR
# from its own location and every context from $HOME, so copying the script
# plus files/claude into a temp tree isolates both sides completely.
# Usage: bash tests/claude-sync-agents.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal exxo exxo-personal; do mkdir -p "$FAKE/.claude-$c"; done
AG="$REPO/files/claude/agents"
SHARED=(implementer reviewer git-pr-ops investigator sanity-cms notion-ops)
printf -- '---\nname: private-probe\ndescription: x\nmodel: haiku\n---\n' > "$AG/private-probe.md"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }

# --- diff is read-only ---
out="$(sync --diff 2>&1)"
check "diff: exxo reports implementer missing" grep -q 'implementer.md: missing (would be linked)' <<<"$out"
check "diff: personal reports would link" grep -q 'agents: would link' <<<"$out"
check "diff: private-probe reported personal-only" grep -q 'personal-only, not linked: private-probe' <<<"$out"
check "diff is read-only (no agents dir created)" \
    test ! -e "$FAKE/.claude-personal/agents" -a ! -e "$FAKE/.claude-exxo/agents"

# --- pre-seed exxo with stale, broken and unmanaged entries ---
mkdir -p "$FAKE/.claude-exxo/agents"
ln -s "$AG/private-probe.md" "$FAKE/.claude-exxo/agents/private-probe.md"
ln -s "$T/nowhere.md" "$FAKE/.claude-exxo/agents/gone.md"
ln -s "$T/elsewhere.md" "$FAKE/.claude-exxo/agents/reviewer.md"
printf -- '---\nname: handmade\ndescription: x\nmodel: haiku\n---\n' > "$FAKE/.claude-exxo/agents/handmade.md"

out="$(sync --diff 2>&1)"
check "diff: wrong-target link reported" grep -q 'reviewer.md: wrong target (would be relinked)' <<<"$out"
check "diff: stale links reported for pruning" grep -q 'would prune: gone.md, private-probe.md' <<<"$out"
check "diff: unmanaged file reported for adoption" grep -q 'unmanaged, would adopt: handmade.md' <<<"$out"

# --- apply ---
sync >"$T/apply1.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply1.log"; }
check "personal agents is a symlink to the repo dir" \
    test "$(readlink "$FAKE/.claude-personal/agents")" = "$AG"
for ctx in exxo exxo-personal; do
    d="$FAKE/.claude-$ctx/agents"
    check "$ctx agents is a real dir" test -d "$d" -a ! -L "$d"
    for n in "${SHARED[@]}"; do
        check "$ctx/$n.md links to repo" test "$(readlink "$d/$n.md")" = "$AG/$n.md"
    done
    check "$ctx: private-probe not linked" test ! -e "$d/private-probe.md" -a ! -L "$d/private-probe.md"
done
check "prunes stale and broken links" test ! -L "$FAKE/.claude-exxo/agents/gone.md"
check "adopts unmanaged real agent file (moved into repo)" test -f "$AG/handmade.md"
check "adopts unmanaged real agent file (gone from context)" test ! -e "$FAKE/.claude-exxo/agents/handmade.md"

# --- second run is idempotent ---
before="$(ls -l "$FAKE/.claude-exxo/agents" | awk '{print $9,$10,$11}')"
sync >"$T/apply2.log" 2>&1
after="$(ls -l "$FAKE/.claude-exxo/agents" | awk '{print $9,$10,$11}')"
check "second run is idempotent (personal)" grep -q 'agents: already linked' "$T/apply2.log"
check "second run is idempotent (exxo listing unchanged)" test "$before" = "$after"
out="$(sync --diff 2>&1)"
check "diff after apply: implementer current" grep -q 'implementer.md: current' <<<"$out"

[ "$fail" = 0 ] && echo "all claude-sync agents tests passed"
exit "$fail"
