#!/bin/bash
# Lint files/claude/agents/*.md: valid subagent frontmatter, and a body that
# restates the environment mechanics a fresh subagent context doesn't inherit.
# Usage: bash tests/claude-agents-lint.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS="$REPO_DIR/files/claude/agents"
EXPECTED=(implementer reviewer git-pr-ops investigator sanity-cms notion-ops)
fail=0
err() { printf 'FAIL: %s\n' "$*"; fail=1; }

for n in "${EXPECTED[@]}"; do
    [ -f "$AGENTS/$n.md" ] || err "missing agent $n.md"
done

for f in "$AGENTS"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f" .md)"
    [ "$(head -1 "$f")" = "---" ] || { err "$base: frontmatter must start on line 1"; continue; }
    fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")"
    body="$(awk 'NR==1{next} f{print} /^---$/{f=1}' "$f")"
    name="$(printf '%s\n' "$fm" | sed -n 's/^name: *//p')"
    desc="$(printf '%s\n' "$fm" | sed -n 's/^description: *//p')"
    model="$(printf '%s\n' "$fm" | sed -n 's/^model: *//p')"
    [ "$name" = "$base" ] || err "$base: name '$name' != file basename"
    case "$name" in *:*) err "$base: name must not contain ':'";; esac
    [ -n "$desc" ] || err "$base: empty description"
    case "$model" in sonnet|opus|haiku|inherit) ;; *) err "$base: model '$model' not sonnet|opus|haiku|inherit";; esac
    printf '%s\n' "$body" | grep -q '^## Environment' || err "$base: no '## Environment' section"
    for s in run-with-secrets SSH worktree; do
        printf '%s\n' "$body" | grep -q "$s" || err "$base: body does not mention $s"
    done
done

[ "$fail" = 0 ] && echo "ok: $(ls "$AGENTS"/*.md | wc -l | tr -d ' ') agents lint clean"
exit "$fail"
