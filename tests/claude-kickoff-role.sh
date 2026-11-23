#!/bin/bash
# Tests for the role-fragment launch of scripts/claude-kickoff. A builder lane
# (frontmatter `role` set, or a body starting with /gaia:planner (legacy /squad-planner); `tier: builder`
# forces it, `tier: attended` opts out) renders its settings with
# `squad roles render --kind K [--overlay openrouter] --interactive` and passes
# `--setting-sources project --settings <json> --append-system-prompt-file
# <roles_dir>/builder-instructions.md --permission-mode auto` (plus --plugin-dir
# <roles_dir>/plugin when that dir exists). An attended lane gets none of that.
# A render failure or a missing squad exits 6. Runs under a fake $HOME with stub
# `claude` and `squad`; nothing real launches.
# Usage: bash tests/claude-kickoff-role.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KICK="$SRC_REPO/scripts/claude-kickoff"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAKE="$(cd "$T" && pwd -P)/home"; BIN="$T/bin"; REC="$T/rec"; SREC="$T/squad-rec"
CFG="$FAKE/.claude-exxo-personal"
W="$FAKE/work/proj"
ROLES_DIR="$FAKE/.config/squad/roles"
mkdir -p "$CFG" "$BIN" "$W" "$ROLES_DIR"
for tool in yq jq; do
    real="$(command -v "$tool" || true)"
    [ -n "$real" ] && ln -s "$real" "$BIN/$tool"
done
cat >"$BIN/claude" <<'EOF2'
#!/bin/bash
for a in "$@"; do printf 'arg<%s>\n' "$a"; done >"$REC"
EOF2
cat >"$BIN/squad" <<'EOF2'
#!/bin/bash
printf '%s\n' "$*" >>"$SREC"
[ -z "${SQUAD_STUB_FAIL:-}" ] || { echo "render failed (stub)" >&2; exit 3; }
echo '{"permissions":{"deny":["Bash(op read*)"]},"env":{"GAIA_TIER":"builder"}}'
EOF2
chmod +x "$BIN/claude" "$BIN/squad"
export CLAUDE_KICKOFF_CONTEXTS="$SRC_REPO/src/.config/claude-kickoff/contexts.toml"
unset CLAUDE_KICKOFF_NO_TRUST_CHECK GAIA_CONFIG
jq -n --arg w "$W" '{projects: {($w): {hasTrustDialogAccepted: true}}}' >"$CFG/.claude.json"
mkdir -p "$FAKE/.claude-exxo-openrouter"
cp "$CFG/.claude.json" "$FAKE/.claude-exxo-openrouter/.claude.json"
mkfile() { # mkfile <name> <extra frontmatter lines> <body>
    printf 'cwd: %s\ncontext: exxo-personal\nmodel: opus\neffort: high\n%s\n---\n%s\n' "$W" "$2" "$3" >"$T/$1.md"
}
mkfile client 'role: client' 'Do the thing.'
mkfile orch 'role: orchestrator' 'Do the thing.'
mkfile infra 'role: infra' 'Do the thing.'
mkfile planner '' $'/gaia:planner\n\nPlan the thing.'
mkfile planner_legacy '' $'/squad-planner\n\nPlan the thing.'
mkfile attended '' 'Do the thing.'
mkfile attended-forced $'role: client\ntier: attended' 'Do the thing.'
mkfile builder-forced 'tier: builder' 'Do the thing.'
mkfile bad-tier 'tier: wizard' 'Do the thing.'
mkfile mention '' 'Plan with /squad-planner later.'
SJ='{"permissions":{"deny":["Bash(op read*)"]},"env":{"GAIA_TIER":"builder"}}'

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
kick() { rm -f "$SREC"; out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" REC="$REC" SREC="$SREC" "$KICK" "$@" 2>&1); rc=$?; }
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }
hasx() { printf '%s\n' "$out" | grep -qxF -- "$1"; }
recs() { tr '\n' ' ' <"$REC"; }
squadargs() { cat "$SREC" 2>/dev/null; }
BASE="arg<--setting-sources> arg<project> arg<--settings> arg<$SJ> arg<--append-system-prompt-file> arg<$ROLES_DIR/builder-instructions.md> arg<--permission-mode> arg<auto> "
TAIL="arg<--model> arg<opus> arg<--effort> arg<high> arg<Do the thing.> "

# --- builder lanes ---
kick "$T/client.md"
check "client launch exits 0" [ "$rc" -eq 0 ]
check "client argv carries the role flags" [ "$(recs)" = "${BASE}${TAIL}" ]
check "client renders kind member, interactive" [ "$(squadargs)" = "roles render --kind member --roles-dir $ROLES_DIR --interactive" ]
kick "$T/orch.md"
check "orchestrator renders kind operator" [ "$(squadargs)" = "roles render --kind operator --roles-dir $ROLES_DIR --interactive" ]
kick "$T/infra.md"
check "infra renders kind infra" [ "$(squadargs)" = "roles render --kind infra --roles-dir $ROLES_DIR --interactive" ]
kick "$T/planner.md"
check "a /gaia:planner body renders kind planner" [ "$(squadargs)" = "roles render --kind planner --roles-dir $ROLES_DIR --interactive" ]
kick "$T/planner_legacy.md"
check "a legacy /squad-planner body still renders kind planner" [ "$(squadargs)" = "roles render --kind planner --roles-dir $ROLES_DIR --interactive" ]
kick "$T/builder-forced.md"
check "tier: builder without a role defaults to kind member" [ "$(squadargs)" = "roles render --kind member --roles-dir $ROLES_DIR --interactive" ]
mkdir -p "$ROLES_DIR/plugin"
kick "$T/client.md"
check "--plugin-dir is added when <roles_dir>/plugin exists" [ "$(recs)" = "arg<--plugin-dir> arg<$ROLES_DIR/plugin> ${BASE}${TAIL}" ]
rmdir "$ROLES_DIR/plugin"
kick "$T/client.md" --account exxo-openrouter
check "openrouter context adds --overlay openrouter" [ "$(squadargs)" = "roles render --kind member --roles-dir $ROLES_DIR --overlay openrouter --interactive" ]
printf '[broker]\nroles_dir = "/tmp/x"\n' >"$FAKE/.config/squad/config.toml"
kick "$T/client.md"
check "[broker] roles_dir is passed to render as --roles-dir" [ "$(squadargs)" = "roles render --kind member --roles-dir /tmp/x --interactive" ]
check "  builder-instructions path is under it" grep -qx "arg<--append-system-prompt-file>" "$REC"
check "  and names /tmp/x/builder-instructions.md" grep -qx "arg</tmp/x/builder-instructions.md>" "$REC"
mkdir -p /tmp/x/plugin
kick "$T/client.md"
check "  plugin dir is taken from it" grep -qx "arg</tmp/x/plugin>" "$REC"
rmdir /tmp/x/plugin 2>/dev/null; rmdir /tmp/x 2>/dev/null
printf '[broker]\nroles_dir = "~/custom-roles"\n' >"$FAKE/.config/squad/config.toml"
kick "$T/client.md"
check "~ in [broker] roles_dir is expanded" bash -c 'grep -qx "arg<$2/custom-roles/builder-instructions.md>" "$1"' _ "$REC" "$FAKE"
printf 'roles_dir = "/tmp/top"\n' >"$FAKE/.config/squad/config.toml"
kick "$T/client.md"
check "top-level roles_dir is ignored (default used)" [ "$(squadargs)" = "roles render --kind member --roles-dir $ROLES_DIR --interactive" ]
rm "$FAKE/.config/squad/config.toml"
printf '[broker]\nroles_dir = "/tmp/viagaia"\n' >"$T/gaia.toml"
GAIA_CONFIG="$T/gaia.toml" kick "$T/client.md"
check "GAIA_CONFIG is honoured" [ "$(squadargs)" = "roles render --kind member --roles-dir /tmp/viagaia --interactive" ]
kick "$T/client.md"
check "default roles dir when no config" [ "$(squadargs)" = "roles render --kind member --roles-dir $ROLES_DIR --interactive" ]
kick "$T/client.md" --resume sess-1 --account exxo-personal --cwd "$W"
check "resume of a builder lane passes the role flags before --resume" bash -c '[ "$(sed -n 1,2p "$1" | tr "\n" " ")" = "arg<--setting-sources> arg<project> " ] && grep -qx "arg<--resume>" "$1"' _ "$REC"

# --- attended lanes ---
kick "$T/attended.md"
check "attended launch exits 0 without squad calls" [ "$rc" -eq 0 ] && [ ! -e "$SREC" ]
check "attended argv has no role flags" [ "$(recs)" = "$TAIL" ]
kick "$T/attended-forced.md"
check "tier: attended beats role" [ "$(recs)" = "$TAIL" ]
kick "$T/mention.md"
check "a body that only mentions /squad-planner stays attended" [ "$(recs)" = "arg<--model> arg<opus> arg<--effort> arg<high> arg<Plan with /squad-planner later.> " ]
kick "$T/bad-tier.md"
check "an unknown tier exits 5" [ "$rc" -eq 5 ]

# --- failures exit 6 and launch nothing ---
rm -f "$REC"
SQUAD_STUB_FAIL=1 kick "$T/client.md"
check "a render failure exits 6" [ "$rc" -eq 6 ]
check "  message names squad roles render" has "squad roles render"
check "  claude was not started" [ ! -e "$REC" ]
SQUAD_STUB_FAIL=1 kick "$T/client.md" --dry-run
check "a render failure also fails --dry-run" [ "$rc" -eq 6 ]
rm "$BIN/squad"
kick "$T/client.md"
check "a missing squad exits 6" [ "$rc" -eq 6 ]
kick "$T/attended.md"
check "a missing squad does not matter for an attended lane" [ "$rc" -eq 0 ]

# --- dry-run ---
cat >"$BIN/squad" <<'EOF2'
#!/bin/bash
printf '%s\n' "$*" >>"$SREC"
echo '{"env":{"GAIA_TIER":"builder"}}'
EOF2
chmod +x "$BIN/squad"
kick "$T/client.md" --dry-run
check "builder dry-run exits 0" [ "$rc" -eq 0 ]
check "  prints tier: builder" hasx "tier: builder"
check "  prints role_fragment: member" hasx "role_fragment: member"
kick "$T/planner.md" --dry-run
check "planner dry-run prints role_fragment: planner" hasx "role_fragment: planner"
kick "$T/attended.md" --dry-run
check "attended dry-run prints tier: attended" hasx "tier: attended"
check "  and role_fragment: none" hasx "role_fragment: none"
kick "$T/client.md" --no-member-deny
check "--no-member-deny is gone" [ "$rc" -eq 2 ]
check "--help no longer documents it" bash -c '! "$1" --help | grep -q -- "--no-member-deny"' _ "$KICK"
check "--help says role makes a session Gaia's and standalone kickoffs leave it out" \
    bash -c '"$1" --help | grep -q "Setting \`role\` makes the session Gaia'"'"'s" && "$1" --help | grep -q "standalone kickoffs leave \`role\` out"' _ "$KICK"

# --- nothing is written ---
snap() { { find "$FAKE" -exec stat -f '%N %m %z' {} + 2>/dev/null | sort; git -C "$SRC_REPO" status --porcelain; } | shasum; }
before=$(snap)
kick "$T/client.md"
kick "$T/client.md" --dry-run
after=$(snap)
check "a launch and a dry-run write nothing in the repo or the fake home" [ "$before" = "$after" ]

if [ "$fail" -eq 0 ]; then echo "all claude-kickoff role tests passed"; else echo "claude-kickoff role tests FAILED"; exit 1; fi
