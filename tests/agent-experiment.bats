#!/usr/bin/env bash
# Standalone TAP-style shell suite. The .bats name keeps the experiment's shell
# tests discoverable without adding Bats as a workstation dependency.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$REPO_DIR/scripts/agent-experiment"
TEST_TMP="$(mktemp -d /tmp/agent-experiment-tests.XXXXXX)"
trap 'rm -rf "$TEST_TMP"' EXIT

test_number=0

ok() {
  test_number=$((test_number + 1))
  printf 'ok %d - %s\n' "$test_number" "$1"
}

fail() {
  test_number=$((test_number + 1))
  printf 'not ok %d - %s\n' "$test_number" "$1" >&2
  exit 1
}

expect_success() {
  local name="$1"
  shift
  if "$@" >"$TEST_TMP/stdout" 2>"$TEST_TMP/stderr"; then
    ok "$name"
  else
    sed -n '1,120p' "$TEST_TMP/stderr" >&2
    fail "$name"
  fi
}

expect_failure_matching() {
  local name="$1" pattern="$2"
  shift 2
  if "$@" >"$TEST_TMP/stdout" 2>"$TEST_TMP/stderr"; then
    fail "$name (unexpected success)"
  elif grep -Eq "$pattern" "$TEST_TMP/stderr"; then
    ok "$name"
  else
    sed -n '1,120p' "$TEST_TMP/stderr" >&2
    fail "$name (missing diagnostic)"
  fi
}

printf '1..12\n'

expect_success "composed h2gc profile validates" \
  "$CLI" validate --profile exxo-h2gc-portal

"$CLI" render --profile exxo-h2gc-portal >"$TEST_TMP/render-one"
"$CLI" render --profile exxo-h2gc-portal >"$TEST_TMP/render-two"
if cmp -s "$TEST_TMP/render-one" "$TEST_TMP/render-two"; then
  ok "render is byte deterministic"
else
  fail "render is byte deterministic"
fi

if grep -q 'just skills-check' "$TEST_TMP/render-one" &&
   grep -q 'agent/run -- <command>' "$TEST_TMP/render-one" &&
   grep -q 'openspec/AGENTS.md' "$TEST_TMP/render-one"; then
  ok "render preserves downstream routing and secret wrapper boundary"
else
  fail "render preserves downstream routing and secret wrapper boundary"
fi

ruby -ryaml -e '
  document = YAML.safe_load(File.read(ARGV.fetch(0)), [], [], false)
  capabilities = document.fetch("capabilities")
  modes = capabilities.map { |capability| capability.fetch("delivery_mode") }.uniq
  statuses = capabilities.map { |capability| capability.fetch("experiment_status") }.uniq
  abort unless %w[instruction-only executable reference-only].all? { |mode| modes.include?(mode) }
  abort unless %w[approved excluded].all? { |status| statuses.include?(status) }
' "$REPO_DIR/files/agent-experiments/contract/capabilities.yaml" || fail "capability category fixtures are complete"
ok "capability category fixtures are complete"

cat >"$TEST_TMP/collision-capabilities.yaml" <<YAML
version: 1
capabilities:
  - id: run-with-secrets
    name: Exxo path
    source_repository: fixture/exxo
    source_root: $TEST_TMP
    required_paths: []
    invocation_contract: agent/run -- <command>
    allowed_audience: [exxo]
    delivery_mode: instruction-only
    experiment_status: approved
    collision_key: run-with-secrets
  - id: homelab-run-with-secrets
    name: Homelab path
    source_repository: fixture/homelab
    source_root: $TEST_TMP
    required_paths: []
    invocation_contract: homelab wrapper
    allowed_audience: [personal]
    delivery_mode: reference-only
    experiment_status: approved
    collision_key: run-with-secrets
YAML
cat >"$TEST_TMP/collision-profile.yaml" <<YAML
version: 1
id: collision-fixture
name: Collision fixture
policy: contract/policy.md
audience: test
capabilities: [run-with-secrets, homelab-run-with-secrets]
exclusions: []
constraints: [fixture only]
YAML
expect_failure_matching "duplicate collision key is actionable" \
  "collision on 'run-with-secrets'.*select exactly one delivery path" \
  "$CLI" validate --profile-file "$TEST_TMP/collision-profile.yaml" \
  --capabilities-file "$TEST_TMP/collision-capabilities.yaml"

cat >"$TEST_TMP/missing-capabilities.yaml" <<YAML
version: 1
capabilities:
  - id: run-with-secrets
    name: Missing skill fixture
    source_repository: fixture/missing
    source_root: $TEST_TMP
    required_paths: [$TEST_TMP/does-not-exist/SKILL.md]
    invocation_contract: agent/run -- <command>
    allowed_audience: [exxo]
    delivery_mode: instruction-only
    experiment_status: approved
    collision_key: run-with-secrets
YAML
cat >"$TEST_TMP/missing-profile.yaml" <<YAML
version: 1
id: missing-fixture
name: Missing fixture
policy: contract/policy.md
audience: test
capabilities: [run-with-secrets]
exclusions: []
constraints: [fixture only]
YAML
expect_failure_matching "missing referenced SKILL.md is rejected" \
  "missing referenced path.*SKILL.md" \
  "$CLI" validate --profile-file "$TEST_TMP/missing-profile.yaml" \
  --capabilities-file "$TEST_TMP/missing-capabilities.yaml"

cat >"$TEST_TMP/redaction-profile.yaml" <<YAML
version: 1
id: redaction-fixture
name: Redaction fixture
policy: contract/policy.md
audience: test
capabilities: []
exclusions: []
constraints: [fixture only]
opaque_fixture: ghp_TESTONLY000000000000000000000000
YAML
if "$CLI" validate --profile-file "$TEST_TMP/redaction-profile.yaml" >"$TEST_TMP/redaction-out" 2>"$TEST_TMP/redaction-err"; then
  fail "credential-shaped fixture is rejected with redaction"
elif grep -q 'credential-shaped value rejected.*value redacted' "$TEST_TMP/redaction-err" &&
     ! grep -q 'ghp_TESTONLY' "$TEST_TMP/redaction-err"; then
  ok "credential-shaped fixture is rejected with redaction"
else
  fail "credential-shaped fixture is rejected with redaction"
fi

protected=(
  "$HOME/claude"
  "$HOME/.claude"
  "$HOME/.claude-exxo"
  "$HOME/.codex"
  "$HOME/.agents"
  "$HOME/Library/Application Support/JetBrains/Air"
  "/Users/tim/dev/dotfiles/files/claude"
  "/Users/tim/dev/exxo/h2gc/h2gc-portal"
)
for destination in "${protected[@]}"; do
  if "$CLI" stage --profile exxo-h2gc-portal --destination "$destination" >"$TEST_TMP/protected-out" 2>"$TEST_TMP/protected-err"; then
    fail "all protected live paths are rejected"
  fi
  grep -q 'protected live destination rejected' "$TEST_TMP/protected-err" || fail "all protected live paths are rejected"
done
ok "all protected live paths are rejected"

nonempty="$TEST_TMP/nonempty"
mkdir "$nonempty"
touch "$nonempty/existing"
expect_failure_matching "stage requires an empty destination" \
  "destination must be empty" \
  "$CLI" stage --profile exxo-h2gc-portal --destination "$nonempty"

stage_dir="$TEST_TMP/happy-stage"
mkdir "$stage_dir"
expect_success "stage writes only the deterministic bundle" \
  "$CLI" stage --profile exxo-h2gc-portal --destination "$stage_dir"
if test -f "$stage_dir/AGENTS.md" &&
   test -f "$stage_dir/PROFILE.json" &&
   test -f "$stage_dir/source-manifest.json" &&
   test "$(find "$stage_dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 3; then
  ok "staged bundle contains only expected files"
else
  fail "staged bundle contains only expected files"
fi

if grep -R -Eq 'gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{16,}|Bearer[[:space:]]+[^[:space:]]+' "$stage_dir"; then
  fail "staged bundle has no credential-shaped values"
else
  ok "staged bundle has no credential-shaped values"
fi
