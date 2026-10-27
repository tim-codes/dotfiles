#!/bin/bash
# Tests for the member deny overlay of scripts/claude-kickoff: every launch passes
# `--settings <repo>/files/claude/settings.member-deny.json` (raw `gh pr merge` and
# `gh api ... merge` denied), --no-member-deny skips it. Runs under a fake $HOME with
# a stub `claude` that records its argv; nothing real launches. Cases: the overlay
# is valid JSON holding only permissions.deny with the merge rules, --dry-run shows
# its path and rules (or `member_deny: off`), a real launch and a resume pass
# --settings before --model, --no-member-deny passes nothing, the symlinked
# src/bin entry finds the same file, a missing or invalid overlay refuses with exit 6
# (and --no-member-deny still launches), and a launch writes nothing: the repo and
# the fake home are identical before and after.
# Usage: bash tests/claude-kickoff-member-deny.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KICK="$SRC_REPO/scripts/claude-kickoff"
OVERLAY="$SRC_REPO/files/claude/settings.member-deny.json"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAKE="$(cd "$T" && pwd -P)/home"; BIN="$T/bin"; REC="$T/rec"
CFG="$FAKE/.claude-exxo-personal"
W="$FAKE/work/proj"
mkdir -p "$CFG" "$BIN" "$W"
for tool in yq jq; do
    real="$(command -v "$tool" || true)"
    [ -n "$real" ] && ln -s "$real" "$BIN/$tool"
done
cat >"$BIN/claude" <<'EOF2'
#!/bin/bash
for a in "$@"; do printf 'arg<%s>\n' "$a"; done >"$REC"
EOF2
chmod +x "$BIN/claude"
export CLAUDE_KICKOFF_CONTEXTS="$SRC_REPO/src/.config/claude-kickoff/contexts.toml"
unset CLAUDE_KICKOFF_NO_TRUST_CHECK
jq -n --arg w "$W" '{projects: {($w): {hasTrustDialogAccepted: true}}}' >"$CFG/.claude.json"
cat >"$T/member.md" <<EOF2
cwd: $W
context: exxo-personal
model: opus
effort: high
---
Do the thing.
EOF2

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
# kickwith <kickoff> <args...>: fake home, stub first on PATH; sets rc, out.
kickwith() { local k="$1"; shift; out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" REC="$REC" "$k" "$@" 2>&1); rc=$?; }
kick() { kickwith "$KICK" "$@"; }
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }
hasx() { printf '%s\n' "$out" | grep -qxF -- "$1"; }
recs() { tr '\n' ' ' <"$REC"; }

# --- the overlay file ---
check "overlay is valid JSON" jq -e . "$OVERLAY" >/dev/null
check "overlay carries only permissions.deny" jq -e '(keys == ["permissions"]) and (.permissions | keys == ["deny"])' "$OVERLAY" >/dev/null
for rule in 'Bash(gh pr merge*)' 'Bash(* gh pr merge*)' 'Bash(gh * pr merge*)' 'Bash(gh api *merge*)'; do
    check "overlay denies $rule" jq -e --arg r "$rule" '.permissions.deny | index($r) != null' "$OVERLAY" >/dev/null
done
check "every overlay rule is a Bash deny rule" jq -e '.permissions.deny | all(type == "string" and startswith("Bash(") and endswith(")"))' "$OVERLAY" >/dev/null

# --- dry-run ---
kick "$T/member.md" --dry-run
check "dry-run exits 0" [ "$rc" -eq 0 ]
check "dry-run prints the overlay path" hasx "member_deny: $OVERLAY"
check "dry-run prints the rules" bash -c 'printf "%s\n" "$1" | grep -F "member_deny_rules: " | grep -qF "Bash(gh pr merge*)" && printf "%s\n" "$1" | grep -F "member_deny_rules: " | grep -qF "Bash(gh api *merge*)"' _ "$out"
kick "$T/member.md" --dry-run --no-member-deny
check "--no-member-deny dry-run exits 0" [ "$rc" -eq 0 ]
check "--no-member-deny prints member_deny: off" hasx "member_deny: off"
check "--no-member-deny prints no rules" bash -c '! printf "%s\n" "$1" | grep -q "member_deny_rules"' _ "$out"
kick "$T/member.md" --resume sess-1 --account exxo-personal --cwd "$W" --dry-run
check "a resume dry-run shows the overlay too" hasx "member_deny: $OVERLAY"
check "--help documents the flag" bash -c '"$1" --help | grep -q -- "--no-member-deny"' _ "$KICK"

# --- real exec of the stub ---
kick "$T/member.md"
check "new launch exits 0 (stub)" [ "$rc" -eq 0 ]
check "new launch argv is --settings <overlay> --model M --effort E <body>" \
    [ "$(recs)" = "arg<--settings> arg<$OVERLAY> arg<--model> arg<opus> arg<--effort> arg<high> arg<Do the thing.> " ]
kick "$T/member.md" --no-member-deny
check "--no-member-deny launch exits 0 (stub)" [ "$rc" -eq 0 ]
check "--no-member-deny launch passes no --settings" [ "$(recs)" = "arg<--model> arg<opus> arg<--effort> arg<high> arg<Do the thing.> " ]
kick "$T/member.md" --resume sess-1 --account exxo-personal --cwd "$W"
check "resume launch passes --settings before --resume" bash -c '[ "$(sed -n 1,4p "$1" | tr "\n" " ")" = "arg<--settings> arg<$2> arg<--resume> arg<sess-1> " ]' _ "$REC" "$OVERLAY"
# alongside add_dirs and deny: --add-dir is variadic, so --settings must close its list
mkdir -p "$FAKE/briefs"
sed 's|^model: .*|&\nadd_dirs: ~/briefs\ndeny: Bash(curl:*)|' "$T/member.md" >"$T/both.md"
kick "$T/both.md"
check "--settings follows --add-dir and precedes --disallowedTools" \
    [ "$(recs)" = "arg<--add-dir> arg<$FAKE/briefs> arg<--settings> arg<$OVERLAY> arg<--disallowedTools> arg<Bash(curl:*)> arg<--model> arg<opus> arg<--effort> arg<high> arg<Do the thing.> " ]

# --- the symlinked entry point (src/bin/claude-kickoff -> ../../scripts/claude-kickoff)
SYM="$SRC_REPO/src/bin/claude-kickoff"
if [ -L "$SYM" ]; then
    kickwith "$SYM" "$T/member.md" --dry-run
    check "via the src/bin symlink the overlay is found" hasx "member_deny: $OVERLAY"
fi
mkdir -p "$T/elsewhere"
ln -s "$KICK" "$T/elsewhere/claude-kickoff"
kickwith "$T/elsewhere/claude-kickoff" "$T/member.md" --dry-run
check "via an absolute symlink elsewhere the overlay is found" hasx "member_deny: $OVERLAY"

# --- a missing or invalid overlay refuses; --no-member-deny still launches
FR="$T/fakerepo"
mkdir -p "$FR/scripts" "$FR/files/claude"
cp "$KICK" "$FR/scripts/claude-kickoff"
rm -f "$REC"
kickwith "$FR/scripts/claude-kickoff" "$T/member.md"
check "a missing overlay refuses with exit 6" [ "$rc" -eq 6 ]
check "  message names the file and the flag" bash -c 'printf "%s\n" "$1" | grep -qF "settings.member-deny.json" && printf "%s\n" "$1" | grep -qF -- "--no-member-deny"' _ "$out"
check "  the stub was not started" [ ! -e "$REC" ]
kickwith "$FR/scripts/claude-kickoff" "$T/member.md" --no-member-deny
check "a missing overlay is fine under --no-member-deny" [ "$rc" -eq 0 ]
echo '{ not json' >"$FR/files/claude/settings.member-deny.json"
kickwith "$FR/scripts/claude-kickoff" "$T/member.md"
check "an invalid overlay refuses with exit 6" [ "$rc" -eq 6 ]
echo '{"permissions": {"deny": []}}' >"$FR/files/claude/settings.member-deny.json"
kickwith "$FR/scripts/claude-kickoff" "$T/member.md"
check "an overlay with no deny rules refuses with exit 6" [ "$rc" -eq 6 ]

# --- nothing is written: the repo and the fake home are identical after a launch
snap() { { find "$FAKE" -exec stat -f '%N %m %z' {} + 2>/dev/null | sort; git -C "$SRC_REPO" status --porcelain; } | shasum; }
before=$(snap)
kick "$T/member.md"
kick "$T/member.md" --dry-run
after=$(snap)
check "a launch and a dry-run write nothing in the repo or the fake home" [ "$before" = "$after" ]

if [ "$fail" -eq 0 ]; then echo "all claude-kickoff member-deny tests passed"; else echo "claude-kickoff member-deny tests FAILED"; exit 1; fi
