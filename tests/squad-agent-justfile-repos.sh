#!/bin/bash
# The live Gaia instance config (src/.config/squad/config.toml) lists the repos whose agent/Justfile
# the permission hook may allow ([broker] agent_justfile_repos, Gaia #426, ENG-788). Each entry has
# the shape Gaia's config parser accepts: "owner/name", the owner literal, the name may be a * glob
# (src/contracts/config.rs AGENT_JUSTFILE_REPO). An entry Gaia would refuse stops the broker from
# loading the config, so it is caught here first. Also: no duplicates, and the list is not empty
# (an empty list silently drops every agent/Justfile allow).
# Usage: bash tests/squad-agent-justfile-repos.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$SRC_REPO/src/.config/squad/config.toml"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

repos="$(yq -p toml -oy '.broker.agent_justfile_repos[]' "$CFG")"
if [ -n "$repos" ]; then ok "agent_justfile_repos is present and not empty"; else bad "agent_justfile_repos is missing or empty"; fi

while IFS= read -r r; do
    [ -z "$r" ] && continue
    if [[ "$r" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.*-]+$ ]]; then
        ok "$r is owner/name"
    else
        bad "$r is not owner/name (the owner literal, the name may be a * glob)"
    fi
done <<<"$repos"

dups="$(printf '%s\n' "$repos" | tr '[:upper:]' '[:lower:]' | sort | uniq -d)"
if [ -z "$dups" ]; then ok "no duplicate entries"; else bad "duplicate entries: $dups"; fi

[ "$fail" = 0 ] && echo "all agent_justfile_repos tests passed"
exit "$fail"
