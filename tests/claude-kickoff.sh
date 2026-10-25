#!/bin/bash
# Exercise scripts/claude-kickoff against a stub `claude` on PATH (nothing real
# ever launches). Two parts: synthetic prompt files under a fake $HOME (both
# frontmatter forms, overrides, resume, every error exit code, a real exec of the
# stub with its argv/env/cwd recorded), then --dry-run over every prompt file in
# the 261024 kickoff batch under the real $HOME, when that directory exists
# (body size must equal the legacy `$(sed '1,/^---$/d' file)` byte count).
# Usage: bash tests/claude-kickoff.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KICK="$SRC_REPO/scripts/claude-kickoff"
FIXTURES="${KICKOFF_FIXTURES:-$HOME/claude/prompts/261024}"
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAKE="$T/home"; BIN="$T/bin"; REC="$T/rec"
mkdir -p "$FAKE/.claude-exxo" "$FAKE/.claude-exxo-openrouter" "$FAKE/.claude-exxo-personal" "$FAKE/.claude-personal" \
         "$FAKE/work/proj/.git" "$FAKE/work/other" "$FAKE/dev/grp/named/.git" "$FAKE/dev/one/dup/.git" \
         "$FAKE/dev/two/dup/.git" "$FAKE/dev/shallow/.git" "$FAKE/dev/x/shallow/.git" "$FAKE/.claude-lab" "$BIN"
# The launcher parses its contexts file with yq (v4); put the real one on the stub PATH.
YQ_REAL="$(command -v yq || true)"
[ -n "$YQ_REAL" ] && ln -s "$YQ_REAL" "$BIN/yq"
# Tests read the repo's contexts file unless a case sets its own.
REPO_CONTEXTS="$SRC_REPO/src/.config/claude-kickoff/contexts.toml"
export CLAUDE_KICKOFF_CONTEXTS="$REPO_CONTEXTS"

# Stub claude: records argc, each argv entry as arg<...> (the body spans lines),
# the env it was given and its cwd.
cat >"$BIN/claude" <<'EOF'
#!/bin/bash
{
  echo "argc=$#"
  for a in "$@"; do printf 'arg<%s>\n' "$a"; done
  echo "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR-unset}"
  echo "TTL=${EXXO_SECRET_CACHE_TTL_SECONDS-unset}"
  echo "PWD=$(pwd -P)"
} >"$REC"
EOF
chmod +x "$BIN/claude"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

# kick <args...>: run in the fake home with the stub first on PATH; sets rc, out.
kick() { out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" REC="$REC" "$KICK" "$@" 2>&1); rc=$?; }
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }
expect_rc() { # expect_rc <desc> <rc> <args...>
    local d="$1" want="$2"; shift 2
    kick "$@"
    if [ "$rc" -eq "$want" ]; then ok "$d (exit $want)"; else bad "$d: exit $rc, wanted $want: $out"; fi
}

W="$FAKE/work/proj"
# fixture form: no opening ---, long free-text values, context with a comment
cat >"$T/fixture.md" <<EOF
cwd: $W
context: exxo (a parenthetical comment mentioning exxo-personal and personal)
model: opus
effort: high
launch: cd somewhere && claude-exxo "\$(sed '1,/^---\$/d' file)"
before launch: a key with a space, ignored
note: unknown keys are ignored: even with colons
---
Do the thing.

Second line with --- inside and trailing text.
EOF
# conventional form: opening --- line
cat >"$T/yaml.md" <<EOF
---
cwd: ~/work/proj
context: personal
model: sonnet
effort: low
---
Body of the conventional form.
EOF

# --- dry-run, both forms ---
kick "$T/fixture.md" --dry-run
check "fixture form dry-run exits 0" [ "$rc" -eq 0 ]
check "dry-run resolves context to the exxo dir" has "config_dir: $FAKE/.claude-exxo"
check "dry-run prints mode, model, effort" [ "$(printf '%s\n' "$out" | grep -cx -e 'mode: new' -e 'model: opus' -e 'effort: high')" -eq 3 ]
check "dry-run prints the cwd" has "cwd: $(cd "$W" && pwd -P)"
check "dry-run prints body size, not the body" bash -c '! printf "%s" "$1" | grep -q "Do the thing" && printf "%s" "$1" | grep -q "^body_bytes: [1-9]"' _ "$out"
kick "$T/yaml.md" --dry-run
check "--- opened form dry-run exits 0" [ "$rc" -eq 0 ]
check "~ in cwd is expanded against HOME" has "cwd: $(cd "$W" && pwd -P)"
check "context personal maps to .claude-personal" has "config_dir: $FAKE/.claude-personal"
check "model/effort from the --- form" bash -c 'printf "%s\n" "$1" | grep -qx "model: sonnet" && printf "%s\n" "$1" | grep -qx "effort: low"' _ "$out"

# --- override and resume (dry-run) ---
kick "$T/fixture.md" --account exxo-personal --dry-run
check "--account overrides context" has "config_dir: $FAKE/.claude-exxo-personal"
kick "$T/fixture.md" --account=personal --dry-run
check "--account=VALUE form works" has "config_dir: $FAKE/.claude-personal"
kick "$T/fixture.md" --resume abc-123_X --dry-run
check "--resume dry-run reports resume mode, id, no body" bash -c 'printf "%s\n" "$1" | grep -qx "mode: resume" && printf "%s\n" "$1" | grep -qx "session_id: abc-123_X" && printf "%s\n" "$1" | grep -q "^body_bytes: 0"' _ "$out"
kick "$T/fixture.md" --resume abc --account exxo-personal --dry-run
check "--resume with --account targets that dir" has "config_dir: $FAKE/.claude-exxo-personal"

# --- real exec of the stub ---
kick "$T/fixture.md"
check "new launch exits 0 (stub)" [ "$rc" -eq 0 ]
rec=$(cat "$REC" 2>/dev/null)
check "new launch argv is --model M --effort E <body> in that order" \
    [ "$(printf '%s\n' "$rec" | sed -n '1,5p' | tr '\n' ' ')" = "argc=5 arg<--model> arg<opus> arg<--effort> arg<high> " ]
check "body passed as one positional arg with its inner --- intact" bash -c '
    printf "%s\n" "$1" | grep -q "Second line with --- inside and trailing text."' _ "$rec"
check "frontmatter keys do not leak into the body" bash -c '! printf "%s\n" "$1" | grep -q "before launch"' _ "$rec"
check "CLAUDE_CONFIG_DIR is the exxo dir" bash -c 'printf "%s\n" "$1" | grep -qx "CLAUDE_CONFIG_DIR=$2"' _ "$rec" "$FAKE/.claude-exxo"
check "TTL defaults to 43200" bash -c 'printf "%s\n" "$1" | grep -qx "TTL=43200"' _ "$rec"
check "claude started in the prompt cwd" bash -c 'printf "%s\n" "$1" | grep -qx "PWD=$2"' _ "$rec" "$(cd "$W" && pwd -P)"
out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin" REC="$REC" EXXO_SECRET_CACHE_TTL_SECONDS=60 "$KICK" "$T/fixture.md" 2>&1)
check "a caller-set TTL is respected" bash -c 'grep -qx "TTL=60" "$1"' _ "$REC"

kick "$T/fixture.md" --resume sess-1 --account exxo-personal
check "resume launch exits 0 (stub)" [ "$rc" -eq 0 ]
rec=$(cat "$REC")
check "resume argv is --resume ID --model M --effort E, no body" \
    [ "$(printf '%s\n' "$rec" | sed -n '1,7p' | tr '\n' ' ')" = "argc=6 arg<--resume> arg<sess-1> arg<--model> arg<opus> arg<--effort> arg<high> " ]
check "resume passes no body" bash -c '! printf "%s\n" "$1" | grep -q "Do the thing"' _ "$rec"
check "resume uses the overridden config dir" bash -c 'printf "%s\n" "$1" | grep -qx "CLAUDE_CONFIG_DIR=$2"' _ "$rec" "$FAKE/.claude-exxo-personal"
check "resume keeps the cwd and TTL" bash -c 'printf "%s\n" "$1" | grep -qx "PWD=$2" && printf "%s\n" "$1" | grep -qx "TTL=43200"' _ "$rec" "$(cd "$W" && pwd -P)"

# --- bare name and home redirect ---
sed 's|^cwd: .*|cwd: named|' "$T/fixture.md" >"$T/bare.md"
kick "$T/bare.md" --dry-run
check "bare cwd name resolves a unique git checkout under ~/dev" has "cwd: $(cd "$FAKE/dev/grp/named" && pwd -P)"
sed 's|^cwd: .*|cwd: ~|' "$T/fixture.md" >"$T/home.md"
kick "$T/home.md" --dry-run
check "cwd ~ is redirected to ~/claude like the wrappers" has "cwd: $(cd "$FAKE" && pwd -P)/claude"

# --- failures: distinct exit codes ---
expect_rc "no arguments is a usage error" 2
expect_rc "unknown option" 2 "$T/fixture.md" --bogus
expect_rc "unknown --account" 2 "$T/fixture.md" --account work --dry-run
expect_rc "--account without a value" 2 "$T/fixture.md" --account
expect_rc "malformed --resume id" 2 "$T/fixture.md" --resume 'a b;c' --dry-run
expect_rc "two prompt files" 2 "$T/fixture.md" "$T/yaml.md"
expect_rc "missing prompt file" 3 "$T/none.md" --dry-run
printf 'cwd: x\nmodel: opus\n' >"$T/noterm.md"
expect_rc "no --- terminator" 3 "$T/noterm.md" --dry-run
printf 'cwd: %s\ncontext: exxo\nmodel: opus\neffort: low\n---\n\n' "$W" >"$T/nobody.md"
expect_rc "empty body on a new session" 3 "$T/nobody.md" --dry-run
expect_rc "empty body is fine on resume" 0 "$T/nobody.md" --resume s1 --dry-run
for k in cwd context model effort; do
    grep -v "^$k:" "$T/fixture.md" >"$T/no-$k.md"
    expect_rc "missing $k" 4 "$T/no-$k.md" --dry-run
    has "'$k'" && ok "  message names $k" || bad "  message does not name $k: $out"
done
expect_rc "--account stands in for a missing context" 0 "$T/no-context.md" --account exxo --dry-run
sed 's|^context: .*|context: work|' "$T/fixture.md" >"$T/badctx.md"
expect_rc "unknown context value" 5 "$T/badctx.md" --dry-run
sed 's|^cwd: .*|cwd: /nonexistent/dir|' "$T/fixture.md" >"$T/badcwd.md"
expect_rc "cwd that is not a directory" 5 "$T/badcwd.md" --dry-run
sed 's|^cwd: .*|cwd: dup|' "$T/fixture.md" >"$T/dup.md"
expect_rc "ambiguous bare cwd name" 5 "$T/dup.md" --dry-run
sed 's|^cwd: .*|cwd: shallow|' "$T/fixture.md" >"$T/shallow.md"
kick "$T/shallow.md" --dry-run
check "shallowest bare-name match wins" has "cwd: $(cd "$FAKE/dev/shallow" && pwd -P)"
sed 's|^cwd: .*|cwd: nowhere|' "$T/fixture.md" >"$T/nowhere.md"
expect_rc "unmatched bare cwd name" 5 "$T/nowhere.md" --dry-run
# --- needs mapping (exit 9) ---
withneeds() { sed "s|^model: .*|&\nneeds: $1|" "$T/fixture.md" >"$T/needs.md"; }
for n in datadog boards; do
    withneeds "$n"
    for c in exxo exxo-personal personal; do expect_rc "needs $n is met in $c" 0 "$T/needs.md" --account "$c" --dry-run; done
    expect_rc "needs $n is unmet in exxo-openrouter" 9 "$T/needs.md" --account exxo-openrouter --dry-run
done
for n in m365 figma notion; do
    withneeds "$n"
    expect_rc "needs $n is met in exxo" 0 "$T/needs.md" --account exxo --dry-run
    for c in exxo-personal personal exxo-openrouter; do expect_rc "needs $n is unmet in $c" 9 "$T/needs.md" --account "$c" --dry-run; done
done
withneeds "agent-run"
for c in exxo exxo-personal personal; do expect_rc "needs agent-run is met in $c" 0 "$T/needs.md" --account "$c" --dry-run; done
expect_rc "needs agent-run is unmet in exxo-openrouter" 9 "$T/needs.md" --account exxo-openrouter --dry-run
withneeds "Datadog, M365 something-else"
expect_rc "needs is case-insensitive, comma or space separated, ignores unknown words" 9 "$T/needs.md" --account personal --dry-run
has "'m365'" && ok "  message names the unmet need" || bad "  message does not name m365: $out"
withneeds "frobnicate"
expect_rc "an unknown need still exits 0" 0 "$T/needs.md" --account exxo --dry-run
has "claude-kickoff: warning: unknown need 'frobnicate' ignored" && ok "  and warns on stderr" || bad "  no warning: $out"
withneeds "datadog"
expect_rc "a known need prints no warning" 0 "$T/needs.md" --account exxo --dry-run
has "warning" && bad "  unexpected warning: $out" || ok "  no warning"
for c in "$FAKE/.claude-exxo-openrouter" "$FAKE/.claude-exxo"; do
    sed "s|^cwd: .*|cwd: $c|" "$T/fixture.md" >"$T/ctxcwd.md"
    expect_rc "cwd in a context dir is redirected" 0 "$T/ctxcwd.md" --dry-run
    has "cwd: $(cd "$FAKE" && pwd -P)/claude" && ok "  to ~/claude" || bad "  not redirected: $out"
done
expect_rc "exxo-openrouter is a known context" 0 "$T/fixture.md" --account exxo-openrouter --dry-run
has "config_dir: $FAKE/.claude-exxo-openrouter" && ok "  maps to its config dir" || bad "  wrong config dir: $out"

# --- contexts from data: a file of our own, the new frontmatter keys, exits 8 and 9 ---
# mkctx <file> <preconditions toml array> writes a two-context file: lab (our own) and exxo-personal.
mkctx() {
    cat >"$1" <<EOF
account_bound = ["m365", "datadog"]

[[context]]
name = "lab"
harness = "claude-code"
config_dir = "~/.claude-lab"
account = "labacct"
provides = ["datadog"]
env = { LAB_VAR = "from-table" }
preconditions = $2

[[context]]
name = "exxo-personal"
harness = "claude-code"
config_dir = "~/.claude-exxo-personal"
account = "personal"
provides = []
env = {}
preconditions = []
EOF
}
LAB="$T/contexts-lab.toml"; mkctx "$LAB" '[]'
kick_with() { # kick_with <contexts file> <args...>
    local f="$1"; shift
    out=$(HOME="$FAKE" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" REC="$REC" CLAUDE_KICKOFF_CONTEXTS="$f" "$KICK" "$@" 2>&1); rc=$?
}
kick_with "$LAB" "$T/fixture.md" --account lab --dry-run
check "a context only in the file is accepted (exit 0)" [ "$rc" -eq 0 ]
check "  prints context: lab" has "context: lab"
check "  prints its account" has "account: labacct"
check "  and its config dir under the fake home" has "config_dir: $FAKE/.claude-lab"
kick_with "$LAB" "$T/fixture.md" --account exxo-openrouter --dry-run
check "a context absent from the file is unknown (exit 2)" [ "$rc" -eq 2 ]
expect_rc "--account nosuch" 2 "$T/fixture.md" --account nosuch --dry-run
sed 's|^context: .*|context: nosuch|' "$T/fixture.md" >"$T/nosuch.md"
expect_rc "an unknown frontmatter context is exit 5" 5 "$T/nosuch.md" --dry-run
# preconditions: in order, stop at the first failure, output discarded
mkdir -p "$T/pre"
mkctx "$T/contexts-pre.toml" "[\"touch $T/pre/ran1\", \"false\", \"touch $T/pre/ran3\"]"
kick_with "$T/contexts-pre.toml" "$T/fixture.md" --account lab --dry-run
check "a failing precondition exits 8" [ "$rc" -eq 8 ]
check "  stderr names the command" has "precondition failed: false"
check "  earlier preconditions ran, later ones did not" bash -c '[ -e "$1/ran1" ] && [ ! -e "$1/ran3" ]' _ "$T/pre"
mkctx "$T/contexts-quiet.toml" '["echo SECRETOUT; echo SECRETERR >&2"]'
kick_with "$T/contexts-quiet.toml" "$T/fixture.md" --account lab --dry-run
check "a passing precondition exits 0 and its output is discarded" bash -c '[ "$1" -eq 0 ] && ! printf "%s" "$2" | grep -q SECRET' _ "$rc" "$out"
# account-bound needs, from the file
withneeds "m365"
expect_rc "needs m365 in exxo-personal (not provided)" 9 "$T/needs.md" --account exxo-personal --dry-run
has "m365" && has "exxo-personal" && ok "  message names the need and the context" || bad "  message: $out"
kick_with "$LAB" "$T/needs.md" --account lab --dry-run
check "needs m365 is unmet in lab (exit 9)" [ "$rc" -eq 9 ]
withneeds "datadog"
kick_with "$LAB" "$T/needs.md" --account lab --dry-run
check "needs datadog is provided by lab" [ "$rc" -eq 0 ]
# harness
sed 's|^model: .*|&\nharness: codex|' "$T/fixture.md" >"$T/codex.md"
expect_rc "harness codex against a claude-code context" 5 "$T/codex.md" --account exxo --dry-run
# new frontmatter keys and the extra dry-run lines
sed '/^before launch:/d' "$T/fixture.md" >"$T/nokeys.md"
kick "$T/nokeys.md" --dry-run
check "defaults: harness claude-code" has "harness: claude-code"
check "defaults: role client, lifetime task, before_launch none" bash -c 'printf "%s\n" "$1" | grep -qx "role: client" && printf "%s\n" "$1" | grep -qx "lifetime: task" && printf "%s\n" "$1" | grep -qx "before_launch: none"' _ "$out"
check "defaults: capabilities none, env_pass none, provides from the table" bash -c 'printf "%s\n" "$1" | grep -qx "capabilities: none" && printf "%s\n" "$1" | grep -qx "env_pass: none" && printf "%s\n" "$1" | grep -q "^provides: .*m365"' _ "$out"
check "the new lines follow the existing ones, in order" bash -c '
    printf "%s\n" "$1" | grep -oE "^(secret_cache_ttl_seconds|harness|account|role|lifetime|needs|capabilities|provides|env_pass|before_launch):" | tr "\n" " " | grep -qx "secret_cache_ttl_seconds: harness: account: role: lifetime: needs: capabilities: provides: env_pass: before_launch: "' _ "$out"
kick "$T/fixture.md" --dry-run
has "before_launch: a key with a space, ignored" && ok "'before launch' (with a space) is read" || bad "no before_launch: $out"
sed 's|^model: .*|&\nbefore-launch: pull first|' "$T/nokeys.md" >"$T/hyph.md"
kick "$T/hyph.md" --dry-run
check "before-launch (hyphen) is read" has "before_launch: pull first"
sed 's|^model: .*|&\nenv-pass: SQUAD_MERGE_AUTHORITY\nrole: herder\ncapabilities: tmux, gh|' "$T/fixture.md" >"$T/keys.md"
kick "$T/keys.md" --dry-run
check "env-pass is echoed as env_pass" has "env_pass: SQUAD_MERGE_AUTHORITY"
check "role herder defaults lifetime to run" bash -c 'printf "%s\n" "$1" | grep -qx "role: herder" && printf "%s\n" "$1" | grep -qx "lifetime: run"' _ "$out"
check "capabilities are echoed" has "capabilities: tmux, gh"
sed 's|^model: .*|&\nlifetime: task\nrole: infra|' "$T/fixture.md" >"$T/life.md"
kick "$T/life.md" --dry-run
check "an explicit lifetime wins over the role default" has "lifetime: task"
sed 's|^model: .*|&\nrole: boss|' "$T/fixture.md" >"$T/badrole.md"
expect_rc "an unknown role is exit 5" 5 "$T/badrole.md" --dry-run
# add_dirs: passed in order as --add-dir, shown in --dry-run, must exist
mkdir -p "$FAKE/briefs" "$FAKE/reports"
sed 's|^model: .*|&\nadd_dirs: ~/briefs, '"$FAKE"'/reports|' "$T/fixture.md" >"$T/adddirs.md"
kick "$T/adddirs.md" --dry-run
check "add_dirs is echoed, ~ expanded, in order" has "add_dirs: $FAKE/briefs $FAKE/reports"
kick "$T/nokeys.md" --dry-run
check "add_dirs defaults to none" has "add_dirs: none"
cat >"$BIN/claude" <<'EOF'
#!/bin/bash
for a in "$@"; do printf 'arg<%s>\n' "$a"; done >"$REC"
EOF
kick "$T/adddirs.md"
check "add_dirs become --add-dir flags, in order, before --model" bash -c '[ "$(sed -n 1,6p "$1" | tr "\n" " ")" = "arg<--add-dir> arg<$2/briefs> arg<--add-dir> arg<$2/reports> arg<--model> arg<opus> " ]' _ "$REC" "$FAKE"
kick "$T/adddirs.md" --resume s1
check "add_dirs also apply on resume" bash -c 'grep -qx "arg<--add-dir>" "$1" && grep -qx "arg<--resume>" "$1"' _ "$REC"
sed 's|^model: .*|&\nadd_dirs: ~/briefs ~/nowhere|' "$T/fixture.md" >"$T/baddirs.md"
expect_rc "a missing add_dirs path" 3 "$T/baddirs.md" --dry-run
has "nowhere" && ok "  message names the path" || bad "  message: $out"
# context env: applied unless the caller set it
cat >"$BIN/claude" <<'EOF'
#!/bin/bash
echo "LAB_VAR=${LAB_VAR-unset}" >"$REC"
EOF
HOME="$FAKE" PATH="$BIN:/usr/bin:/bin" REC="$REC" CLAUDE_KICKOFF_CONTEXTS="$LAB" "$KICK" "$T/fixture.md" --account lab >/dev/null 2>&1
check "context env is applied to claude" grep -qx "LAB_VAR=from-table" "$REC"
HOME="$FAKE" PATH="$BIN:/usr/bin:/bin" REC="$REC" LAB_VAR=caller CLAUDE_KICKOFF_CONTEXTS="$LAB" "$KICK" "$T/fixture.md" --account lab >/dev/null 2>&1
check "a caller-set variable is not overwritten" grep -qx "LAB_VAR=caller" "$REC"
# every repo context applies its TTL env (as #176 did for all of them)
cat >"$BIN/claude" <<'EOF'
#!/bin/bash
echo "TTL=${EXXO_SECRET_CACHE_TTL_SECONDS-unset}" >"$REC"
EOF
for c in exxo exxo-personal personal exxo-openrouter; do
    kick "$T/fixture.md" --account "$c" --dry-run
    check "$c dry-run prints secret_cache_ttl_seconds: 43200" has "secret_cache_ttl_seconds: 43200"
    kick "$T/fixture.md" --account "$c"
    check "$c launch exports the TTL" grep -qx "TTL=43200" "$REC"
done
# a yq that is not v4 is refused
mkdir -p "$T/pybin"; printf '#!/bin/sh\necho "yq 3.4.1"\n' >"$T/pybin/yq"; chmod +x "$T/pybin/yq"
out=$(HOME="$FAKE" PATH="$T/pybin:/usr/bin:/bin" "$KICK" "$T/fixture.md" --dry-run 2>&1); rc=$?
check "a non-v4 yq is exit 7" [ "$rc" -eq 7 ]
# yq missing
out=$(HOME="$FAKE" PATH="/usr/bin:/bin" "$KICK" "$T/fixture.md" --dry-run 2>&1); rc=$?
check "yq missing is exit 7" [ "$rc" -eq 7 ]
has "yq is not on PATH" && ok "  and says so" || bad "  message: $out"

# --- OpenRouter routing env is scrubbed outside exxo-openrouter, as the wrappers do ---
cat >"$BIN/claude" <<'EOF'
#!/bin/bash
{ echo "CFG=${CLAUDE_CONFIG_DIR-unset}"; env | grep -E '^(ANTHROPIC_|CLAUDE_CODE_SUBAGENT_MODEL=)' | sed 's/=.*//' | sort | tr '\n' ' '; echo; } >"$REC"
EOF
for c in exxo exxo-openrouter; do
    HOME="$FAKE" PATH="$BIN:/usr/bin:/bin" REC="$REC" ANTHROPIC_BASE_URL=x ANTHROPIC_API_KEY=x CLAUDE_CODE_SUBAGENT_MODEL=x "$KICK" "$T/fixture.md" --account "$c" >/dev/null 2>&1
    if [ "$c" = exxo ]; then check "exxo launch drops the OpenRouter env" bash -c '! grep -q "ANTHROPIC_\|SUBAGENT" "$1"' _ "$REC"
    else check "exxo-openrouter launch keeps its env" bash -c 'grep -q "ANTHROPIC_BASE_URL" "$1"' _ "$REC"; fi
done

# --- drift guard: the contexts file must match the fish wrappers ---
FISH="$SRC_REPO/src/.config/fish/common.fish"
want_ctx() { yq -p toml -oy '.context[].name' "$REPO_CONTEXTS" | sort; }
want_dirs() { yq -p toml -oy '.context[] | .name + " " + .config_dir' "$REPO_CONTEXTS" | sort; }
fish_dirs() { grep -m1 'set -l ctx_dirs' "$FISH" | grep -o '\.claude-[a-z-]*' | sed 's/^\.claude-//' | sort; }
fish_funcs() { grep -o '^function claude-[a-z-]* ' "$FISH" | sed 's/^function claude-//; s/ $//' | grep -v '^default$' | sort; }
check "drift guard: every context's config_dir is ~/.claude-<name>" [ "$(want_dirs)" = "$(want_ctx | sed 's|.*|& ~/.claude-&|')" ]
check "drift guard: CONTEXTS is non-empty" [ -n "$(want_ctx)" ]
check "drift guard: CONTEXTS equals the ctx_dirs in __claude_ctx" [ "$(want_ctx)" = "$(fish_dirs)" ]
check "drift guard: CONTEXTS equals the claude-<context> wrapper functions" [ "$(want_ctx)" = "$(fish_funcs)" ]
want_env() { grep -m1 '^OPENROUTER_ENV=' "$KICK" | sed 's/^OPENROUTER_ENV="\(.*\)"$/\1/' | tr ' ' '\n' | sort; }
fish_env() { grep -m1 'for v in ANTHROPIC_BASE_URL' "$FISH" | sed 's/^ *for v in //' | tr ' ' '\n' | sort; }
check "drift guard: OPENROUTER_ENV is non-empty" [ -n "$(want_env)" ]
check "drift guard: OPENROUTER_ENV equals the scrub list in __claude_ctx" [ "$(want_env)" = "$(fish_env)" ]

rmdir "$FAKE/.claude-personal"
expect_rc "missing config dir" 6 "$T/yaml.md" --dry-run
mkdir -p "$T/yqbin"; ln -s "$YQ_REAL" "$T/yqbin/yq"
HOME="$FAKE" PATH="$T/yqbin:/usr/bin:/bin" "$KICK" "$T/fixture.md" --dry-run >/dev/null 2>&1; rc=$?
check "claude not on PATH (exit 7)" [ "$rc" -eq 7 ]

# --- every kickoff prompt of the 261024 batch, real HOME, stub claude ---
if [ -d "$FIXTURES" ] && [ -d "$REAL_HOME/.claude-exxo" ] && [ -d "$REAL_HOME/dev" ]; then
    for f in "$FIXTURES"/*.md; do
        name=$(basename "$f")
        out=$(PATH="$BIN:$PATH" "$KICK" "$f" --dry-run 2>&1); rc=$?
        if grep -q '^cwd:' "$f"; then
            # same as `$(sed '1,/^---$/d' file)`: trailing newlines are trimmed
            want=$(printf '%s' "$(sed '1,/^---$/d' "$f")" | wc -c | tr -d ' ')
            if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 's/^body_bytes: //p')" = "$want" ] \
               && ! printf '%s\n' "$out" | grep -q 'EXXO_SECRET\|CLAUDE_CODE'; then
                ok "fixture $name: dry-run ok ($(printf '%s\n' "$out" | grep -E '^(context|model|effort):' | tr '\n' ' '))"
            else bad "fixture $name: exit $rc: $out"; fi
            if [ "$name" = 02-ario-golive.md ]; then
                check "fixture $name: before_launch is non-empty" bash -c 'printf "%s\n" "$1" | grep "^before_launch: ." | grep -qv "^before_launch: none"' _ "$out"
            fi
        else
            if [ "$rc" -eq 3 ]; then ok "fixture $name: not a kickoff file, refused (exit 3)"
            else bad "fixture $name: expected exit 3, got $rc: $out"; fi
        fi
    done
else
    echo "skip: no fixtures at $FIXTURES (or ~/.claude-exxo / ~/dev missing)"
fi

[ "$fail" -eq 0 ] && echo "all claude-kickoff tests passed" || echo "claude-kickoff tests FAILED"
exit "$fail"
