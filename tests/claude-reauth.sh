#!/bin/bash
# Exercise scripts/claude-reauth against PATH stubs for every CLI it calls and a
# fake $HOME — never the real tools, contexts or logins. Each stub has an "ok"
# and a "missing" variant (STUB_<tool>=ok|missing), logs every invocation, and
# salts its output with SECRETLEAK wherever the real tool would print a token,
# id or URL; the script must never let that reach the terminal.
# Usage: bash tests/claude-reauth.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; FAKE="$T/home"; BIN="$T/bin"; STATE="$T/state"
mkdir -p "$REPO/scripts" "$REPO/files/claude" "$FAKE/dev/homelab" "$BIN" "$STATE"
cp "$SRC_REPO/scripts/claude-reauth" "$REPO/scripts/"
cp "$SRC_REPO/files/claude/reauth-needed.toml" "$REPO/files/claude/"
touch "$FAKE/dev/homelab/justfile"
for c in personal reserve exxo exxo-personal; do mkdir -p "$FAKE/.claude-$c"; done
ln -s "$(command -v jq)" "$BIN/jq"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

# --- stubs -------------------------------------------------------------------
# Shared prelude: log the call; "up NAME" is true when STUB_NAME=ok or a login
# stub has since created $STATE/NAME (so run mode can flip a check to ok).
prelude='echo "$(basename "$0") $*" >>"$STATE/calls.log"
up() { local v="STUB_$1"; [ "${!v:-ok}" = ok ] || [ -e "$STATE/$1" ]; }'
stub() { printf '#!/bin/bash\nSTATE=%q\n%s\n%s\n' "$STATE" "$prelude" "$2" >"$BIN/$1"; chmod +x "$BIN/$1"; }

stub docker '
case "$1" in
  info) up docker && { echo "Server: SECRETLEAK"; exit 0; }
        echo "Cannot connect to the Docker daemon at unix:///x/docker.sock. Is the docker daemon running?" >&2; exit 1 ;;
  ps)   up docker && up cache && echo "0123abcd"; exit 0 ;;
  run)  touch "$STATE/cache"; echo "SECRETLEAK-container-id"; exit 0 ;;
esac'
stub orb 'touch "$STATE/docker"; echo "SECRETLEAK"'
stub agent-tooling 'echo "secret cache at redis://127.0.0.1:6380: reachable"; echo "  SECRETLEAK 3"'
stub just 'touch "$STATE/cache"; echo "homelab-1p-cache up SECRETLEAK"'
stub op '
case "$1" in
  whoami) up op && { echo "{\"url\":\"my.1password.com\",\"email\":\"t@example.com\",\"user_uuid\":\"SECRETLEAK\",\"account_uuid\":\"SECRETLEAK\"}"; exit 0; }
          echo "[ERROR] 2026/10/23 04:07:03 account is not signed in" >&2; exit 1 ;;
  account) [ "${STUB_opaccount:-ok}" = ok ] && echo "[{\"email\":\"t@example.com\",\"url\":\"my.1password.com\",\"user_uuid\":\"SECRETLEAK\"}]" || echo "[]"; exit 0 ;;
  signin) touch "$STATE/op"; exit 0 ;;
esac'
stub gcloud '
case "$*" in
  "auth list"*) up gcloud && echo "t@example.com"; exit 0 ;;
  "auth print-access-token"*) up gcloud && { echo "ya29.SECRETLEAK"; exit 0; }
      echo "ERROR: (gcloud.auth.print-access-token) Reauthentication failed. SECRETLEAK" >&2; exit 1 ;;
  "auth application-default print-access-token"*) up adc && { echo "ya29.SECRETLEAK"; exit 0; }
      echo "ERROR: Your default credentials were not found. SECRETLEAK" >&2; exit 1 ;;
  "auth application-default login"*) touch "$STATE/adc"; exit 0 ;;
  "auth login"*) touch "$STATE/gcloud"; exit 0 ;;
esac'
stub gh '
case "$*" in
  "auth status"*) up gh && { printf "github.com\n  ✓ Logged in to github.com account tim-test (keyring)\n  - Token: gho_SECRETLEAK\n"; exit 0; }
      echo "You are not logged into any GitHub hosts. SECRETLEAK" >&2; exit 1 ;;
  "auth login"*) touch "$STATE/gh"; exit 0 ;;
esac'
stub glab '
case "$*" in
  "auth status"*) up glab && { printf "gitlab.com\n  ✓ Logged in to gitlab.com as tim-test (keyring)\n  ✓ Token found in operating system keyring: glpat-SECRETLEAK\n"; exit 0; }
      echo "x gitlab.com: authentication failed SECRETLEAK" >&2; exit 1 ;;
  "auth login"*) touch "$STATE/glab"; exit 0 ;;
esac'
stub pulumi '
case "$1" in
  whoami) up pulumi && { echo "tim-test"; exit 0; }
          echo "error: PULUMI_ACCESS_TOKEN must be set SECRETLEAK" >&2; exit 255 ;;
  env)    up esc && { echo "org/SECRETLEAK-env"; exit 0; }; exit 255 ;;
  login)  touch "$STATE/pulumi" "$STATE/esc"; exit 0 ;;
esac'
AZ_STUB='
case "$1" in
  account) up az && { echo "t@example.com"; exit 0; }
           echo "Please run '"'"'az login'"'"' to setup account. SECRETLEAK" >&2; exit 1 ;;
  login)   touch "$STATE/az"; echo "[{\"id\":\"SECRETLEAK\"}]"; exit 0 ;;
esac'
stub az "$AZ_STUB"
# claude mcp list/get/login. Every needed server is connected unless
# STUB_mcp_<ctx>=missing, which flips that context's first needed server to
# "Needs authentication" and drops its optional servers.
stub claude '
ctx="$(basename "$CLAUDE_CONFIG_DIR")"; ctx="${ctx#.claude-}"; v="STUB_mcp_${ctx//-/_}"
st() { if [ "${!v:-ok}" = ok ] || [ -e "$STATE/mcp-$ctx-$1" ]; then echo "✔ Connected"; else echo "! Needs authentication"; fi; }
case "$1 $2" in
  "mcp list")
    echo "Checking MCP server health…"; echo
    case "$ctx" in
      personal|reserve) echo "Sanity: https://mcp.sanity.io?k=SECRETLEAK (HTTP) - $(st Sanity)"
                echo "mantine: npx -y @mantine/mcp-server SECRETLEAK - ✔ Connected"
                echo "workos: https://mcp.workos.com/SECRETLEAK (HTTP) - ✔ Connected"
                for s in Notion Slack Figma; do echo "claude.ai $s: https://x/SECRETLEAK - ✔ Connected"; done ;;
      exxo)     echo "datadog: https://mcp.datadoghq.eu/v1/mcp?SECRETLEAK (HTTP) - $(st datadog)"
                echo "workos: https://mcp.workos.com/SECRETLEAK (HTTP) - ✔ Connected"
                for s in "Microsoft 365" Notion Slack Figma; do echo "claude.ai $s: https://x/SECRETLEAK - ✔ Connected"; done
                [ "${!v:-ok}" = ok ] && echo "claude.ai Datadog: https://x/SECRETLEAK - ✔ Connected" ;;
      exxo-personal) echo "datadog: https://mcp.datadoghq.eu/v1/mcp (HTTP) - $(st datadog)"
                echo "workos: https://mcp.workos.com/SECRETLEAK (HTTP) - ✔ Connected" ;;
    esac
    echo "playwright: npx @playwright/mcp@latest SECRETLEAK - ✔ Connected"
    echo "plugin:x:broken: https://x/SECRETLEAK (HTTP) - ✘ Failed to connect — SECRETLEAK" ;;
  "mcp get")   printf "%s:\n  Status: %s\n  URL: https://x/SECRETLEAK\n" "$3" "$(st "$3")" ;;
  "mcp login") touch "$STATE/mcp-$ctx-$3"; exit 0 ;;
esac'

# Run the script with only the stubs (and system basics) on PATH.
run() { env -i HOME="$FAKE" PATH="$BIN:/usr/bin:/bin" STATE="$STATE" ${STUBENV[@]+"${STUBENV[@]}"} \
        "$REPO/scripts/claude-reauth" "$@" </dev/null; }
reset() { rm -f "$STATE"/*; STUBENV=(); }
row() { grep -E "^  $1 +$2( |\$)" <<<"$summary" >/dev/null; }
logins() { grep -E ' (auth login|application-default login|signin|login|start)( |$)|^docker run|^just ' "$STATE/calls.log" 2>/dev/null; }
go() { out="$(run "$@" 2>&1)"; rc=$?; summary="$(sed -n '/^== Summary/,$p' <<<"$out")"; }
noleak() { ! grep -q SECRETLEAK <<<"$out"; }
nologin() { [ -z "$(logins)" ]; }

# --- argument handling ---------------------------------------------------------
reset; go --bogus
check "unknown argument exits 2" test "$rc" -eq 2
check "unknown argument prints usage" grep -q '^Usage: claude-reauth' <<<"$out"
reset; go --context nope
check "bad --context exits 2" test "$rc" -eq 2
reset; go --ttl-hours x
check "bad --ttl-hours exits 2" test "$rc" -eq 2
reset; go --help
check "--help exits 0" test "$rc" -eq 0

# --- everything ok ---------------------------------------------------------------
reset; go --check
check "all ok: exit 0" test "$rc" -eq 0
for r in docker exxo-secret-cache homelab-secret-cache 1password gh glab gcloud gcloud-adc pulumi az \
         'mcp:personal:Sanity' 'mcp:personal:mantine' 'mcp:personal:playwright' \
         'mcp:reserve:Sanity' 'mcp:reserve:mantine' 'mcp:reserve:playwright' \
         'mcp:exxo:datadog' 'mcp:exxo:workos' 'mcp:exxo:claude.ai Microsoft 365' \
         'mcp:exxo:claude.ai Datadog' 'mcp:exxo-personal:datadog'; do
    check "all ok: $r ok" row "$r" ok
done
check "all ok: unlisted failing server is ignored" bash -c '! grep -q broken <<<"$1"' _ "$out"
check "all ok: user email shown" grep -q 't@example.com' <<<"$summary"
check "all ok: TTL hint carries 12h in seconds" grep -q 'EXXO_SECRET_CACHE_TTL_SECONDS=43200' <<<"$out"
check "all ok: no secret-like output" noleak
check "all ok: --check runs no login" nologin

reset; go --check --ttl-hours 4
check "--ttl-hours 4 → 14400s" grep -q 'EXXO_SECRET_CACHE_TTL_SECONDS=14400' <<<"$out"

# --- each CLI missing, one at a time (--check) ---------------------------------
for t in gcloud gh glab pulumi az; do
    reset; STUBENV=("STUB_$t=missing"); go --check
    check "$t missing: exit 1" test "$rc" -eq 1
    check "$t missing: row needs-auth" row "$t" needs-auth
    check "$t missing: no secret-like output" noleak
    check "$t missing: --check runs no login" nologin
done
reset; STUBENV=(STUB_adc=missing); go --check
check "ADC missing: gcloud-adc needs-auth" row gcloud-adc needs-auth
check "ADC missing: gcloud itself ok" row gcloud ok
check "ADC missing: hint names the login" grep -q 'gcloud auth application-default login' <<<"$summary"
reset; STUBENV=(STUB_esc=missing); go --check
check "ESC unreachable: pulumi needs-auth" row pulumi needs-auth

reset; STUBENV=(STUB_op=missing); go --check
check "op idle with an account: ok (Touch ID on next use)" row 1password ok
check "op idle: exit 0" test "$rc" -eq 0
reset; STUBENV=(STUB_op=missing STUB_opaccount=missing); go --check
check "op with no account: needs-auth" row 1password needs-auth
check "op with no account: exit 1" test "$rc" -eq 1

reset; STUBENV=(STUB_docker=missing); go --check
check "docker down: docker needs-auth" row docker needs-auth
check "docker down: caches skipped" row exxo-secret-cache skipped
check "docker down: --check does not start OrbStack" nologin
check "docker down: exit 1" test "$rc" -eq 1
reset; STUBENV=(STUB_cache=missing); go --check
check "cache down: exxo cache needs-auth" row exxo-secret-cache needs-auth
check "cache down: --check does not start it" nologin

rm "$BIN/az"
reset; go --check
check "az not installed: skipped" row az skipped
check "az not installed: exit 0" test "$rc" -eq 0
stub az "$AZ_STUB"

# --- MCP ---------------------------------------------------------------------
reset; STUBENV=(STUB_mcp_exxo=missing); go --check
check "mcp exxo: datadog needs-auth" row 'mcp:exxo:datadog' needs-auth
check "mcp exxo: optional absent → skipped" row 'mcp:exxo:claude.ai Datadog' skipped
check "mcp exxo: personal still ok" row 'mcp:personal:Sanity' ok
check "mcp exxo: in-session step names the launcher" grep -q 'claude-exxo' <<<"$out"
check "mcp exxo: in-session step names the server" grep -qF '/mcp → select "datadog"' <<<"$out"
check "mcp exxo: exit 1" test "$rc" -eq 1
check "mcp exxo: no secret-like output" noleak

reset; go --check --context personal
check "--context personal: no exxo rows" bash -c '! grep -qE "^  (gcloud|pulumi|az|exxo-secret-cache|mcp:exxo)" <<<"$1"' _ "$summary"
check "--context personal: personal MCP rows" row 'mcp:personal:Sanity' ok
reset; go --check --context reserve
check "--context reserve: counts as personal (no exxo rows)" bash -c '! grep -qE "^  (gcloud|pulumi|az|exxo-secret-cache|mcp:exxo)" <<<"$1"' _ "$summary"
check "--context reserve: homelab cache row, like personal" row homelab-secret-cache ok
check "--context reserve: only that context's MCP" bash -c '! grep -qE "^  mcp:(personal|exxo|exxo-personal):" <<<"$1"' _ "$summary"
check "--context reserve: Sanity row" row 'mcp:reserve:Sanity' ok
reset; STUBENV=(STUB_mcp_reserve=missing); go --check --context reserve
check "reserve mcp missing: Sanity needs-auth" row 'mcp:reserve:Sanity' needs-auth
check "reserve mcp missing: step names claude-reserve" grep -q 'claude-reserve' <<<"$out"
reset; go --check --context exxo-personal
check "--context exxo-personal: only that context's MCP" bash -c '! grep -qE "^  mcp:(personal|reserve|exxo):" <<<"$1"' _ "$summary"
check "--context exxo-personal: datadog row" row 'mcp:exxo-personal:datadog' ok
rm -rf "$FAKE/.claude-exxo-personal"
reset; go --check --context exxo-personal
check "missing context dir: skipped" row 'mcp:exxo-personal' skipped
mkdir -p "$FAKE/.claude-exxo-personal"

# --- run mode (default): logins run one at a time, then a re-check -------------
reset; STUBENV=(STUB_gcloud=missing STUB_adc=missing STUB_docker=missing STUB_cache=missing STUB_az=missing STUB_mcp_exxo=missing); go
check "run: gcloud login ran" grep -q '^gcloud auth login' "$STATE/calls.log"
check "run: ADC login ran" grep -q '^gcloud auth application-default login' "$STATE/calls.log"
check "run: OrbStack started" grep -q '^orb start' "$STATE/calls.log"
check "run: exxo cache started after Docker came up" grep -q '^docker run -d --rm --name exxo-1p-cache' "$STATE/calls.log"
check "run: az login ran" grep -q '^az login' "$STATE/calls.log"
check "run: mcp login ran for the exxo server" grep -q '^claude mcp login datadog' "$STATE/calls.log"
check "run: everything ok afterwards → exit 0" test "$rc" -eq 0
check "run: gcloud now ok" row gcloud ok
check "run: mcp now ok" row 'mcp:exxo:datadog' ok
check "run: prints a report before the summary" grep -q '^== Report' <<<"$out"
check "run: no secret-like output" noleak

# Logins that need a terminal are not attempted without one (stdin is /dev/null).
reset; STUBENV=(STUB_gh=missing STUB_glab=missing STUB_pulumi=missing); go
check "run, no tty: gh login not attempted" bash -c '! grep -q "^gh auth login" "$1"' _ "$STATE/calls.log"
check "run, no tty: pulumi login not attempted" bash -c '! grep -q "^pulumi login" "$1"' _ "$STATE/calls.log"
check "run, no tty: gh still needs-auth" row gh needs-auth
check "run, no tty: glab still needs-auth" row glab needs-auth
check "run, no tty: glab login not attempted" bash -c '! grep -q "^glab auth login" "$1"' _ "$STATE/calls.log"
check "run, no tty: hint says a terminal is needed" grep -q 'needs a terminal' <<<"$summary"
check "run, no tty: exit 1" test "$rc" -eq 1

# An idle 1Password CLI session is refreshed in run mode (unlocks the app).
reset; STUBENV=(STUB_op=missing); go
check "run: op signin refreshes an idle session" grep -q '^op signin' "$STATE/calls.log"
check "run: op ok afterwards" row 1password ok

# glab not installed: skipped, never blocks (last: removes the stub).
reset; rm -f "$BIN/glab"; go --check
check "glab absent: row skipped" row glab skipped
check "glab absent: exit 0" test "$rc" -eq 0

[ "$fail" = 0 ] && echo "all claude-reauth tests passed"
exit "$fail"
