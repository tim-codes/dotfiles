#!/bin/bash
# Exercise claude-sync's settings merge against a throwaway repo copy and a
# fake $HOME — never the real contexts (same isolation as
# claude-sync-agents.sh). Checks that permission rule arrays from the shared
# and account fragments are concatenated rather than replaced, and that the
# personal context never receives the Exxo grants.
# Usage: bash tests/claude-sync-permissions.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"
mkdir -p "$REPO/scripts" "$REPO/files" "$FAKE"
cp "$SRC_REPO/scripts/claude-sync" "$REPO/scripts/"
cp -R "$SRC_REPO/files/claude" "$REPO/files/"
for c in personal reserve exxo exxo-personal exxo-openrouter; do mkdir -p "$FAKE/.claude-$c"; done
C="$REPO/files/claude"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
sync() { HOME="$FAKE" "$REPO/scripts/claude-sync" "$@"; }
has() { jq -e --arg r "$3" ".permissions.$2 | index([\$r]) != null" "$FAKE/.claude-$1/settings.json" >/dev/null; }

# A shared rule duplicated in the account fragment must appear once.
jq '.permissions.allow += ["WebSearch"]' "$C/settings.exxo.json" > "$T/x" && mv "$T/x" "$C/settings.exxo.json"

sync >"$T/apply.log" 2>&1 || { bad "apply exited non-zero"; cat "$T/apply.log"; }

# Test-isolation guard: the sync must only ever touch the fake HOME.
check "isolated: repo copy and fake HOME live under the temp dir" \
    bash -c '[[ "$1" == "$3"/* && "$2" == "$3"/* ]]' _ "$REPO" "$FAKE" "$T"

shared_allow="$(jq '.permissions.allow | length' "$C/settings.shared.json")"
shared_deny="$(jq '.permissions.deny | length' "$C/settings.shared.json")"
for ctx in personal reserve exxo exxo-personal; do
    want_deny="$shared_deny"
    check "$ctx keeps the whole shared allow set" \
        test "$(jq '[.permissions.allow[]] | length' "$FAKE/.claude-$ctx/settings.json")" -ge "$shared_allow"
    check "$ctx keeps the whole deny floor" \
        test "$(jq '.permissions.deny | length' "$FAKE/.claude-$ctx/settings.json")" -eq "$want_deny"
    check "$ctx keeps defaultMode" \
        test "$(jq -r '.permissions.defaultMode' "$FAKE/.claude-$ctx/settings.json")" = auto
    check "$ctx has git status grant" has "$ctx" allow 'Bash(git status:*)'
    for r in mcp__squad__set mcp__squad__ack mcp__squad__raise mcp__squad__land; do
        check "$ctx has $r grant" has "$ctx" allow "$r"
    done
done
for ctx in personal reserve exxo exxo-personal; do
    check "$ctx gets the Exxo cloud grants" has "$ctx" allow 'Bash(agent-tooling:*)'
    check "$ctx: duplicate rule appears once" \
        test "$(jq '[.permissions.allow[] | select(. == "WebSearch")] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 1
done
for ctx in personal reserve exxo exxo-personal; do
    check "$ctx: GCP reads go through gcp-ro" has "$ctx" allow 'Bash(agent-tooling gcp-ro:*)'
    check "$ctx: no bare gcloud allows" \
        test "$(jq '[.permissions.allow[] | select(test("^Bash\\(gcloud "))] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 0
    check "$ctx: no middle-wildcard gcloud grants" \
        test "$(jq '[.permissions.allow[] | select(test("^Bash\\(gcloud \\*"))] | length' "$FAKE/.claude-$ctx/settings.json")" -eq 0
    check "$ctx: agent-tooling mail send asks" has "$ctx" ask 'Bash(agent-tooling mail send*)'
    check "$ctx: wrapped agent-tooling mail send asks" has "$ctx" ask 'Bash(agent/run -- agent-tooling mail send*)'
    check "$ctx: ./-wrapped agent-tooling mail send asks" has "$ctx" ask 'Bash(./agent/run -- agent-tooling mail send*)'
    check "$ctx: gcloud compute ssh is denied" has "$ctx" deny 'Bash(gcloud compute ssh*)'
    check "$ctx: nested gcloud compute ssh is denied" has "$ctx" deny 'Bash(* gcloud compute ssh*)'
done
# deniedMcpServers lives only in the shared fragment, so the plain deep-merge
# must carry the whole array into every context (it silences the unauthenticated
# claude.ai-synced plugin servers).
shared_denied="$(jq '.deniedMcpServers | length' "$C/settings.shared.json")"
for ctx in personal reserve exxo exxo-personal; do
    check "$ctx keeps all $shared_denied deniedMcpServers entries" \
        test "$(jq '.deniedMcpServers | length' "$FAKE/.claude-$ctx/settings.json")" -eq "$shared_denied"
done
check "deniedMcpServers is non-empty" test "$shared_denied" -gt 0
check "personal and reserve settings are identical" cmp -s "$FAKE/.claude-personal/settings.json" "$FAKE/.claude-reserve/settings.json"
check "personal gets the exxo-skills marketplace" \
    jq -e '.extraKnownMarketplaces["exxo-skills"].source.url == "git@github.com:Exxo-Labs/skills.git"' "$FAKE/.claude-personal/settings.json"
check "personal enables exxo-common" jq -e '.enabledPlugins["exxo-common@exxo-skills"] == true' "$FAKE/.claude-personal/settings.json"
check "personal enables gaia and exxo-ops from the attended fragment" \
    jq -e '.enabledPlugins["gaia@gaia"] == true and .enabledPlugins["exxo-ops@exxo-skills"] == true and .extraKnownMarketplaces.gaia.source.url == "git@github.com:Exxo-Labs/gaia.git"' "$FAKE/.claude-personal/settings.json"
for ctx in personal reserve exxo exxo-personal; do
    check "$ctx enables exxo-mantine (context parity)" jq -e '.enabledPlugins["exxo-mantine@exxo-skills"] == true' "$FAKE/.claude-$ctx/settings.json"
done
for ctx in exxo exxo-personal; do
    check "$ctx enables gaia and exxo-ops" \
        jq -e '.enabledPlugins["gaia@gaia"] and .enabledPlugins["exxo-ops@exxo-skills"] and (.extraKnownMarketplaces | has("gaia"))' "$FAKE/.claude-$ctx/settings.json"
    check "$ctx still enables exxo-common and exxo-mantine" \
        jq -e '.enabledPlugins["exxo-common@exxo-skills"] and .enabledPlugins["exxo-mantine@exxo-skills"]' "$FAKE/.claude-$ctx/settings.json"
done

# --- Shared base vs attended fragment (tier split) -------------------------
# The builder tier stops loading Tim's user settings, so the broad pairing
# scope lives in settings.attended.json and nothing of it may be in shared.
ATT="$C/settings.attended.json"
SHARED="$C/settings.shared.json"
check "attended fragment exists and is valid JSON" jq -e . "$ATT"
# every rule the attended fragment owns, per list
ATT_GRANTS=(
    'Bash(just --justfile=agent/Justfile:*)' 'Bash(just --justfile agent/Justfile:*)'
    'Bash(gh pr create:*)' 'Bash(gh pr ready:*)' 'Bash(gh pr edit:*)' 'Bash(gh pr merge:*)'
    'Bash(gh pr comment:*)' 'Bash(gh pr update-branch:*)'
    'mcp__claude_ai_Notion' 'mcp__claude_ai_Notion__notion-delete-pages'
    'Artifact' 'ArtifactData' 'ArtifactComments'
    'Bash(gh api:*)' 'Bash(git push:*)' 'Bash(git tag:*)'
    'Bash(gh issue list:*)' 'Bash(gh repo view:*)' 'Bash(gh repo list:*)'
    'Bash(gh project view:*)' 'Bash(gh project item-list:*)'
    'mcp__playwright__browser_snapshot' 'mcp__playwright__browser_navigate'
    'mcp__playwright__browser_console_messages' 'mcp__playwright__browser_network_requests'
    'Read(//Users/tim/scratch/claude/**)' 'Edit(//Users/tim/scratch/claude/**)' 'Write(//Users/tim/scratch/claude/**)'
    'Read(//private/tmp/claude-501/**)'
    'Read(//Users/tim/claude/artefacts/**)' 'Edit(//Users/tim/claude/artefacts/**)' 'Write(//Users/tim/claude/artefacts/**)'
    'Bash(wc:*)' 'Bash(grep:*)' 'Bash(ls:*)' 'Bash(cat:*)' 'Bash(tree:*)' 'Bash(find:*)'
    'Bash(git ls-tree:*)' 'Bash(npm view:*)'
    'mcp__Sanity__query_documents' 'mcp__plugin_linear_linear__list_issues'
)
ATT_ASKS=(
    'mcp__claude_ai_Notion__notion-delete-databases'
    'Bash(git push*main*)' 'Bash(git push*master*)'
    'Bash(find *-delete*)' 'Bash(find *-exec*)' 'Bash(find *-execdir*)' 'Bash(find *-ok*)' 'Bash(find *-fprint*)'
    'Bash(pulumi up*)' 'Bash(* pulumi up*)'
    'Bash(gh secret set*)' 'Bash(gh variable set*)'
    'Bash(gh api *-X*)' 'Bash(gh api *--method*)' 'Bash(gh api *-f*)' 'Bash(gh api *-F*)'
    'Bash(gh api *--field*)' 'Bash(gh api *--raw-field*)' 'Bash(gh api *--input*)'
    'mcp__claude_ai_Slack__slack_send_message' 'mcp__claude_ai_Microsoft_365__outlook_send_mail'
    'mcp__claude_ai_Microsoft_365__teams_send_chat_message'
    'Bash(ps:*)' 'Bash(pgrep:*)' 'Bash(gcloud config set*)' 'Bash(kubectl config use-context*)' 'Bash(aws-use*)'
)
ctxs="personal exxo exxo-personal exxo-openrouter"
for r in "${ATT_GRANTS[@]}"; do
    check "attended fragment allows $r" jq -e --arg r "$r" '.permissions.allow | index($r) != null' "$ATT"
    check "shared base carries no attended grant: $r" \
        jq -e --arg r "$r" '((.permissions.allow // []) | index($r)) == null' "$SHARED"
    for ctx in $ctxs; do check "$ctx has attended grant $r" has "$ctx" allow "$r"; done
done
for r in "${ATT_ASKS[@]}"; do
    check "attended fragment asks $r" jq -e --arg r "$r" '.permissions.ask | index($r) != null' "$ATT"
    check "shared base carries no attended ask: $r" \
        jq -e --arg r "$r" '((.permissions.ask // []) | index($r)) == null' "$SHARED"
    for ctx in $ctxs; do check "$ctx has attended ask $r" has "$ctx" ask "$r"; done
done
check "notion-delete-pages is not asked anywhere (soft delete, allow)" \
    bash -c '! jq -e "(.permissions.ask // []) | index(\"mcp__claude_ai_Notion__notion-delete-pages\")" "$1" >/dev/null' _ "$ATT"
check "attended fragment has no deny floor of its own" \
    jq -e '(.permissions.deny // []) | length == 0' "$ATT"
# never-grant list, in every fragment
for f in "$SHARED" "$ATT" "$C/settings.exxo.json" "$C/settings.personal.json"; do
    check "$(basename "$f"): no never-grant wildcard" \
        jq -e '[(.permissions.allow // [])[] | select(test("^Bash\\((\\*|just:\\*|git:\\*|node:\\*|python3?:\\*|npx:\\*|pnpm:\\*|bash:\\*|curl:\\*)\\)$"))] | length == 0' "$f"
done
check "attended gh api read form: no write flags in allows" \
    jq -e '[.permissions.allow[] | select(startswith("Bash(gh api") and test("-X|--method|-f |-F |--input|--field"))] | length == 0' "$ATT"
# deny floor verbatim in every context, from shared
for ctx in $ctxs; do
    for r in 'Bash(op read*)' 'Bash(* op read*)' 'Bash(*--reveal*)' 'Bash(*--show-secrets*)' \
             'Bash(pulumi env open*)' 'Bash(esc env open*)' 'Bash(gcloud secrets versions access*)' \
             'Read(**/.claude.json)' 'Read(**/.credentials.json)'; do
        check "$ctx deny floor: $r" has "$ctx" deny "$r"
    done
done
# attended-only hooks left shared and sit in attended; the rest stay shared
hooks_with() { jq -r --arg m "$2" '[.hooks[]?[]?.hooks[]?.command | select(contains($m))] | length' "$1"; }
for m in 'tmux-home' 'notchbar-agents-claude-hook' 'tmux-claude-hatch' 'claude-config-audit'; do
    check "shared base carries no $m hook" test "$(hooks_with "$SHARED" "$m")" -eq 0
    check "attended fragment carries the $m hook" test "$(hooks_with "$ATT" "$m")" -gt 0
    for ctx in $ctxs; do
        check "$ctx still runs the $m hook" \
            test "$(hooks_with "$FAKE/.claude-$ctx/settings.json" "$m")" -eq "$(hooks_with "$ATT" "$m")"
    done
done
for m in 'squad hook' 'claude-scratch-persist' 'guard-dotfiles-checkout' 'preserve-worktree-transcripts' 'claude-agent-model-guard'; do
    check "shared base keeps the $m hook" test "$(hooks_with "$SHARED" "$m")" -gt 0
    check "attended fragment does not carry the $m hook" test "$(hooks_with "$ATT" "$m")" -eq 0
done
# order: shared -> attended -> account
check "merge order: shared hooks precede attended hooks (SessionStart)" \
    jq -e '(.hooks.SessionStart | map(.hooks[0].command) ) as $c
           | ([$c | to_entries[] | select(.value | contains("claude-scratch-persist")) | .key] | .[0]) as $s
           | ([$c | to_entries[] | select(.value | contains("tmux-home")) | .key] | .[0]) as $a
           | $s < $a' "$FAKE/.claude-personal/settings.json"
check "exxo-openrouter keeps its overlay denies" \
    bash -c 'jq -e "(.permissions.deny | length) > 0 and .env.ENABLE_TOOL_SEARCH == \"false\"" "$1"' _ "$FAKE/.claude-exxo-openrouter/settings.json"

out="$(sync --diff 2>&1)"
check "diff after apply: settings identical" test "$(grep -c '^  identical' <<<"$out")" -ge 4

[ "$fail" = 0 ] && echo "all claude-sync permissions tests passed"
exit "$fail"
