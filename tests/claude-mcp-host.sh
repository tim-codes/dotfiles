#!/bin/bash
# Tests for scripts/claude-mcp-host. A fake repo copy holds a test-host
# fragment, $CLAUDE_CONFIG_DIR is a temp dir, and a stub `claude` on PATH
# logs its arguments, so the real ~/.claude.json is never touched.
# Usage: bash tests/claude-mcp-host.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/repo/scripts" "$T/repo/files/claude" "$T/cfg"
cp "$SRC_REPO/scripts/claude-mcp-host" "$T/repo/scripts/"
cat >"$T/repo/files/claude/mcp.host.testbox.json" <<'JSON'
{"mcpServers": {"local-thing": {"type": "http", "url": "http://127.0.0.1:1/mcp"}}}
JSON
cat >"$T/bin/claude" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$CLAUDE_STUB_LOG"
STUB
chmod +x "$T/bin/claude"
export PATH="$T/bin:$PATH" CLAUDE_CONFIG_DIR="$T/cfg" CLAUDE_STUB_LOG="$T/log"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }
run() { : >"$T/log"; CLAUDE_MCP_HOST="$1" bash "$T/repo/scripts/claude-mcp-host" ${2:+"$2"} 2>&1; }

# a: a host with no fragment is a silent no-op
OUT="$(run otherbox)"; [ -z "$OUT" ] && [ ! -s "$T/log" ] && ok "a: no fragment, no output, no calls" || bad "a: $OUT"

# b: missing server is added with add-json at user scope
OUT="$(run testbox.lan)"
grep -q '^mcp add-json -s user local-thing {"type":"http","url":"http://127.0.0.1:1/mcp"}$' "$T/log" \
    && ok "b: added via add-json (domain suffix stripped)" || bad "b: $(cat "$T/log") / $OUT"

# c: --diff reports but calls nothing
OUT="$(run testbox --diff)"
case "$OUT" in *"local-thing: missing"*) [ ! -s "$T/log" ] && ok "c: --diff is read-only" || bad "c: called claude";; *) bad "c: $OUT";; esac

# d: already-current server is skipped
echo '{"mcpServers":{"local-thing":{"type":"http","url":"http://127.0.0.1:1/mcp"}}}' >"$T/cfg/.claude.json"
OUT="$(run testbox)"
case "$OUT" in *"local-thing: current"*) [ ! -s "$T/log" ] && ok "d: current server untouched" || bad "d: called claude";; *) bad "d: $OUT";; esac

# e: a drifted server is removed then re-added
echo '{"mcpServers":{"local-thing":{"type":"http","url":"http://127.0.0.1:2/mcp"}}}' >"$T/cfg/.claude.json"
OUT="$(run testbox)"
[ "$(head -1 "$T/log")" = "mcp remove -s user local-thing" ] && grep -q '^mcp add-json' "$T/log" \
    && ok "e: drifted server replaced" || bad "e: $(cat "$T/log")"

exit $fail
