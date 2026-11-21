#!/bin/bash
# Lint files/claude/skills/*: SKILL.md frontmatter and the content the
# remaining skills must carry.
# Usage: bash tests/claude-skills-lint.sh
# Scope: every directory under files/claude/skills/ except synced/ (claude.ai
# account cache).
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
# fmq <file> <key>: like fm, with one pair of surrounding single quotes stripped.
fmq() { fm "$1" "$2" | sed "s/^'\(.*\)'\$/\1/"; }
# strict_yaml <file>: the frontmatter parses as strict YAML (yq) and is a mapping.
strict_yaml() { awk 'NR==1{next} /^---$/{exit} {print}' "$1" | yq -e '. | type == "!!map"' >/dev/null; }
shared_skills_list() {
    bash -c 'source <(sed -n "/^shared_skills()/,/^}/p" "$1/scripts/claude-sync"); shared_skills' _ "$REPO_DIR"
}
is_shared() { shared_skills_list | grep -qx "$1"; }
exists_and_shared() { [ -f "$SKILLS/$1/SKILL.md" ] || { echo "no $1/SKILL.md"; return 1; }; is_shared "$1" || { echo "$1 not in shared_skills()"; return 1; }; }
not_shared() { is_shared "$1" && { echo "$1 still in shared_skills()"; return 1; }; return 0; }
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

# Skill prose never enumerates accounts or context dirs (they come from the
# squad config's accounts[]).
no_context_dirs() { ! grep -nE -- '\.claude-(personal|exxo|reserve|default)\b' "$1"/*.md; }


# --- Every in-scope skill: frontmatter ---------------------------------------
for dir in "$SKILLS"/*/; do
    dir="${dir%/}"
    s="$(basename "$dir")"
    [ "$s" = synced ] && continue
    f="$dir/SKILL.md"
    check "$s: SKILL.md exists" test -f "$f"
    [ -f "$f" ] || continue
    check "$s: frontmatter starts on line 1 and closes" \
        sh -c '[ "$(head -1 "$1")" = "---" ] && awk "NR>1 && /^---\$/{f=1} END{exit !f}" "$1"' _ "$f"
    name="$(fm "$f" name)"
    check "$s: name equals directory" test "$name" = "$s"
    check "$s: name is 1-64 of [a-z0-9-]" sh -c 'printf "%s" "$1" | grep -qE "^[a-z0-9-]{1,64}$"' _ "$name"
    check "$s: frontmatter is valid strict YAML" strict_yaml "$f"
    desc="$(fmq "$f" description)"
    check "$s: description is one non-empty line of at most 1024 characters" \
        sh -c '[ -n "$1" ] && case "$1" in ">"*|"|"*) exit 1;; esac && [ "$(printf "%s" "$1" | wc -m)" -le 1024 ]' _ "$desc"
done

# --- retired: the squad skills (gaia plugin) and mantine-* skills (exxo-mantine plugin)
for s_ in squad-member squad-planner squad-leader squad-debug-review mantine-docs mantine-form mantine-combobox mantine-custom-components; do
    check "$s_: retired, not in the repo" test ! -e "$SKILLS/$s_"
    check "$s_: not shared" not_shared "$s_"
done

# --- build-lead (multi-lane build procedure) --------------------------------
B="$SKILLS/build-lead/SKILL.md"
check "build-lead exists and is shared" exists_and_shared build-lead
check "build-lead SKILL.md is at most 250 lines" sh -c '[ "$(wc -l < "$1")" -le 250 ]' _ "$B"
check "build-lead has its sections and references" has_headings "$B" \
    '## 1. Setup' '## 2. Lane briefs' '## 3. Review loop per checkpoint' '## 4. Merging' \
    '## 5. Cross-plan seams' '## 6. Scope changes mid-build' '## 7. Final'
check "build-lead carries its key rules" contains "$B" subagent-driven-development testlock \
    'Ruling:' 'cost if wrong' '--no-ff' 'Never touch the integration worktree' worktree-closedown
check "build-lead references exist" test -f "$SKILLS/build-lead/references/dispatch-templates.md" -a -f "$SKILLS/build-lead/references/lessons.md"

# --- ux-designer (experimental, shared to exxo contexts) -------------------------------
U="$SKILLS/ux-designer/SKILL.md"
generic_only() { ! grep -nE '7797|squad/gui|localhost:[0-9]+|[Mm]antine' "$@" | grep -viE 'e\.g\.|example'; }
check "ux-designer exists" test -f "$U"
check "ux-designer is shared" bash -c '(source <(sed -n "/^shared_skills()/,/^}/p" "$1/scripts/claude-sync"); shared_skills | grep -qx ux-designer)' _ "$REPO_DIR"
check "ux-designer carries the section headings" has_headings "$U" \
    '## Inputs' '## Setup' '## 1. Critique' '## 2. Draft directions' '## 3. Tim chooses' '## 4. Build and review (optional)' '## 5. Wrap-up' '## Figma' '## Rules'
check "ux-designer names the scratchpad, SharePoint and Figma create_new_file" contains "$U" \
    'scratchpad' 'Microsoft 365 connector' 'create_new_file' 'client snapshot' 'design:design-handoff'
check "ux-designer has no peer or launcher flow" sh -c '! grep -nE "ux-designer-peer|SendMessage|ListAgents|window: @|kill-session|handshake|builder" "$1"' _ "$U"
check "ux-designer has no brief template in the skill dir" test ! -e "$SKILLS/ux-designer/brief-template.md"
check "ux-designer description is marked experimental" sh -c 'case "$1" in Experimental:*) ;; *) exit 1;; esac' _ "$(fmq "$U" description)"
check "ux-designer skill is generic" generic_only "$U"
check "ux-designer names no context directory" no_context_dirs "$SKILLS/ux-designer"

[ "$fail" = 0 ] && echo "ok: skills lint clean"
exit "$fail"
