#!/bin/bash
# Exercise src/bin/worktree-copy-local-env against throwaway git repos only -
# never a real checkout or a real env file. Fixture files hold obvious fake
# placeholders; one carries a sentinel that must never appear in the output.
# Usage: bash tests/worktree-copy-local-env.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SRC_REPO/src/bin/worktree-copy-local-env"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT

export HOME="$T/home" GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"
git config --global user.name test
git config --global user.email test@example.invalid
git config --global commit.gpgsign false
git config --global init.defaultBranch main
git config --global protocol.file.allow always

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

SENTINEL="FAKE-SENTINEL-DO-NOT-PRINT"
P="$T/primary"; W="$T/wt"
git init -q "$P"
mkdir -p "$P/deploy" "$P/gui" "$P/apps/web" "$P/node_modules/pkg" "$P/secretsdir" "$P/nested-repo"
printf '.env\n.env.*\n!.env.example\nagent.env\n.envrc\n*.local.*\nnode_modules/\nsecretsdir/\nnested-repo/\n' >"$P/.gitignore"
echo placeholder >"$P/.env.example"
echo placeholder >"$P/README.md"
git -C "$P" add -A
git -C "$P" commit -q -m init
# nested-repo is an independent checkout inside the primary.
git init -q "$P/nested-repo"

printf 'KEY=%s\n' "$SENTINEL" >"$P/.env"
chmod 600 "$P/.env"
echo placeholder >"$P/agent.env"
echo placeholder >"$P/deploy/.env"
chmod 600 "$P/deploy/.env"
echo placeholder >"$P/gui/.env.local"
echo placeholder >"$P/apps/web/app.local.json"
echo placeholder >"$P/secretsdir/.env"
echo placeholder >"$P/node_modules/pkg/.env"
echo placeholder >"$P/nested-repo/.env"
echo placeholder >"$P/unrelated.txt"
ln -s "$P/.env" "$P/link.local.env"

git -C "$P" worktree add -q -b feature "$W"
# An existing file in the worktree must survive untouched.
echo EXISTING >"$W/agent.env"

OUT="$T/out"; ERR="$T/err"
bash "$SCRIPT" "$W" "$P" >"$OUT" 2>"$ERR"; rc=$?

check "exit status 0" test "$rc" -eq 0
check "root .env copied" test -f "$W/.env"
check "nested deploy/.env copied" test -f "$W/deploy/.env"
check "nested gui/.env.local copied" test -f "$W/gui/.env.local"
check "apps/web/app.local.json copied (existing behaviour)" test -f "$W/apps/web/app.local.json"
check "existing agent.env not overwritten" grep -q EXISTING "$W/agent.env"
check "tracked .env.example not reported" bash -c "! grep -q 'env.example' '$OUT'"
check "node_modules/pkg/.env not copied" test ! -e "$W/node_modules/pkg/.env"
check "nested git repo .env not copied" test ! -e "$W/nested-repo/.env"
check "symlink not copied" test ! -e "$W/link.local.env" -a ! -L "$W/link.local.env"
check "unrelated file not copied" test ! -e "$W/unrelated.txt"
mode() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null; }
check "root .env mode 600 preserved" test "$(mode "$W/.env")" = 600
check "deploy/.env mode 600 preserved" test "$(mode "$W/deploy/.env")" = 600
check "output names deploy/.env" grep -q 'copied deploy/.env' "$OUT"
check "output keeps format for root file" grep -q '^worktree-copy-local-env: copied \.env$' "$OUT"
check "sentinel never printed" bash -c "! grep -rq '$SENTINEL' '$OUT' '$ERR'"

# Fully ignored directory (not a prune-listed name) still yields its env file.
check "ignored non-build dir .env copied" test -f "$W/secretsdir/.env"

# Dry run changes nothing and is idempotent on re-run.
rm -rf "$W/deploy"
bash "$SCRIPT" -n "$W" "$P" >"$OUT" 2>&1
check "dry run lists deploy/.env" grep -q 'would copy deploy/.env' "$OUT"
check "dry run copies nothing" test ! -e "$W/deploy/.env"
bash "$SCRIPT" "$W" "$P" >"$OUT" 2>&1
check "re-run restores deploy/.env" test -f "$W/deploy/.env"
bash "$SCRIPT" "$W" "$P" >"$OUT" 2>&1
check "second run copies nothing" bash -c "! grep -q copied '$OUT'"

exit "$fail"
