#!/bin/bash
# Gaia's role fragments (contracts/roles) must carry no attended-fragment rule
# (files/claude/settings.attended.json) and no never-grant wildcard (an interpreter,
# curl, just:*, git:*, Bash(*)), and every kind fragment must carry the deny floor.
# The check is `claude-config-audit --roles`, run here against the squad repo's
# fragments. Skips unless GAIA_CONTRACTS_DIR names the contracts directory
# (<dir>/roles holds the fragments); GAIA_CONTRACTS_REQUIRED=1 turns the skip into
# a failure.
# Usage: GAIA_CONTRACTS_DIR=~/dev/squad/contracts bash tests/squad-roles-attended-leak.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLES="${GAIA_CONTRACTS_DIR:-}/roles"
if [ -z "${GAIA_CONTRACTS_DIR:-}" ] || [ ! -d "$ROLES" ]; then
    if [ "${GAIA_CONTRACTS_REQUIRED:-}" = 1 ]; then
        echo "FAIL: no role fragments readable (GAIA_CONTRACTS_DIR=${GAIA_CONTRACTS_DIR:-unset})"; exit 1
    fi
    echo "skip: no role fragments readable (set GAIA_CONTRACTS_DIR to the squad contracts directory)"
    exit 0
fi
out="$("$SRC_REPO/scripts/claude-config-audit" --roles "$ROLES" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
    echo "ok:   role fragments in $ROLES: deny floor present, no attended rule, no never-grant wildcard"
    exit 0
fi
printf '%s\n' "$out"
echo "FAIL: role fragments in $ROLES break the role floor"
exit 1
