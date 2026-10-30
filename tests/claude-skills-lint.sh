#!/bin/bash
# Lint files/claude/skills/*: SKILL.md frontmatter, no retired squad v0.4
# command or skill name in the squad v0.5 skills, and the content those skills
# must carry.
# Usage: bash tests/claude-skills-lint.sh
#
# Scope: every directory under files/claude/skills/ except synced/ (claude.ai
# account cache) and the vendored skills named in files/claude/vendor/*.lock.json.
# The retired-name patterns apply to RETIRED_SCOPE only while the v0.4 skills
# are still live; the P8 cut-over (P7 Task 1) widens it to every in-scope skill
# and adds the "retired skill is gone" checks.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$REPO_DIR/files/claude/skills"
export LC_ALL=en_US.UTF-8
fail=0

ok() { printf 'ok: %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
# check <description> <command...>: ok/FAIL on the command's exit status; on
# failure the command's output (e.g. file:line of an offending match) follows.
check() {
    local desc=$1 out
    shift
    if out="$("$@" 2>&1)"; then
        ok "$desc"
    else
        bad "$desc"
        [ -z "$out" ] || printf '%s\n' "$out" | sed 's/^/    /'
    fi
}
# fm <file> <key>: the single-line frontmatter value of <key>.
fm() { awk 'NR==1{next} /^---$/{exit} {print}' "$1" | sed -n "s/^$2: *//p" | head -1; }
shared_skills_list() {
    bash -c 'source <(sed -n "/^shared_skills()/,/^}/p" "$1/scripts/claude-sync"); shared_skills' _ "$REPO_DIR"
}
is_shared() { shared_skills_list | grep -qx "$1"; }
exists_and_shared() { [ -f "$SKILLS/$1/SKILL.md" ] || { echo "no $1/SKILL.md"; return 1; }; is_shared "$1" || { echo "$1 not in shared_skills()"; return 1; }; }
# contains <file> <fixed string>...: every string occurs in the file.
contains() {
    local f=$1 s rc=0
    shift
    for s in "$@"; do grep -qF -- "$s" "$f" 2>/dev/null || { echo "missing: $s"; rc=1; }; done
    return "$rc"
}
# has_headings <file> <heading>...: each heading is a whole line of the file.
has_headings() {
    local f=$1 h rc=0
    shift
    for h in "$@"; do grep -qxF -- "$h" "$f" 2>/dev/null || { echo "missing heading: $h"; rc=1; }; done
    return "$rc"
}

RETIRED_PATTERNS=(
    '(^|`)[[:space:]]*squad (send|ack|set|subscribe|unsubscribe|publish|register|deregister|roster|get|history|operator|herd|heavy|job|jobs|mail|trunk|prompt)\b'
    '(^|`)[[:space:]]*squad debug (on|off|status|dir|list)\b'
    '/?squad-(orchestrator|herder|concierge|liaison|infra|join)\b'
    '\bsquad-pr-merge\b'
    '\bsquad-prompt-hook\b'
    'claude-kickoff [^`]*--resume'
)
RETIRED_SCOPE=(squad-member)

no_retired_names() {
    local dir=$1 p rc=0
    for p in "${RETIRED_PATTERNS[@]}"; do
        if grep -nE -- "$p" "$dir"/*.md; then rc=1; fi
    done
    return "$rc"
}
# Skill prose never enumerates accounts or context dirs (they come from the
# squad config's accounts[]).
no_context_dirs() { ! grep -nE -- '\.claude-(personal|exxo|reserve|default)\b' "$1"/*.md; }

vendored="$(jq -r '.skills[]' "$REPO_DIR"/files/claude/vendor/*.lock.json 2>/dev/null)"

# --- Every in-scope skill: frontmatter ---------------------------------------
for dir in "$SKILLS"/*/; do
    dir="${dir%/}"
    s="$(basename "$dir")"
    [ "$s" = synced ] && continue
    printf '%s\n' "$vendored" | grep -qx "$s" && continue
    f="$dir/SKILL.md"
    check "$s: SKILL.md exists" test -f "$f"
    [ -f "$f" ] || continue
    check "$s: frontmatter starts on line 1 and closes" \
        sh -c '[ "$(head -1 "$1")" = "---" ] && awk "NR>1 && /^---\$/{f=1} END{exit !f}" "$1"' _ "$f"
    name="$(fm "$f" name)"
    check "$s: name equals directory" test "$name" = "$s"
    check "$s: name is 1-64 of [a-z0-9-]" sh -c 'printf "%s" "$1" | grep -qE "^[a-z0-9-]{1,64}$"' _ "$name"
    desc="$(fm "$f" description)"
    check "$s: description is one non-empty line of at most 1024 characters" \
        sh -c '[ -n "$1" ] && case "$1" in ">"*|"|"*) exit 1;; esac && [ "$(printf "%s" "$1" | wc -m)" -le 1024 ]' _ "$desc"
done

for s in "${RETIRED_SCOPE[@]}"; do
    [ -d "$SKILLS/$s" ] || continue
    check "$s: no retired command or skill name" no_retired_names "$SKILLS/$s"
    check "$s: names no context directory" no_context_dirs "$SKILLS/$s"
done

# --- squad-member (P7 Task 2) ------------------------------------------------
M="$SKILLS/squad-member/SKILL.md"
check "squad-member exists and is shared" exists_and_shared squad-member
check "squad-member names every member tool" contains "$M" \
    mcp__squad__set mcp__squad__ack mcp__squad__raise mcp__squad__land mcp__squad__heavy_slot \
    mcp__squad__delegate mcp__squad__delegate_result mcp__squad__job_review mcp__squad__watch mcp__squad__unwatch
check "squad-member teaches the turn format" contains "$M" '<squad-message' 'ack_required:' 'priority="now"'
check "squad-member never registers" sh -c '! grep -n "call[^.]*mcp__squad__register" "$1" | grep -iv never' _ "$M"
check "squad-member carries the section headings" has_headings "$M" \
    '## Turns' '## Status and questions' '## Testing and trunks' '## Landing' '## Heavy jobs' \
    '## Delegating and serving jobs' '## Watches' '## Repo conventions' '## Infra helpers' '## Finishing'

[ "$fail" = 0 ] && echo "ok: skills lint clean"
exit "$fail"
