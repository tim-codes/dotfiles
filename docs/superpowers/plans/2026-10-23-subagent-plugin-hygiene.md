# Subagent and Plugin Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship six purpose-dedicated subagent definitions on cheaper models to every context, route the delegation policy through them, drop the unused Notion/Vercel plugins, and make the usage scanner a repo script with a recorded baseline.

**Architecture:** Agent definitions live in `files/claude/agents/<name>.md`. `scripts/claude-sync` gains an `agents/` delivery path that mirrors the skills path exactly: personal gets a whole-directory symlink, every other context gets a curated real directory of per-file symlinks drawn from a `shared_agents()` allow list. Plugin changes are fragment edits. The scanner becomes `scripts/claude-usage-scan` (stdlib Python, `python3 -I`) with a `headline` block per period and `--compare`.

**Tech Stack:** bash + jq (claude-sync), Python 3 stdlib (scanner), Claude Code subagent markdown frontmatter.

**Spec:** `docs/superpowers/specs/2026-10-23-subagent-plugin-hygiene-design.md`

## Global Constraints

- Agent frontmatter: `name` (equals the file basename, no `:`), `description`, `model`; `model` is one of `sonnet`, `opus`, `haiku`, `inherit`. All six round-one agents pin `model: sonnet`.
- All six agents are shared to exxo: `implementer`, `reviewer`, `git-pr-ops`, `investigator`, `sanity-cms`, `notion-ops`.
- Each agent body restates the environment mechanics subagents don't inherit: secret cache via `run-with-secrets` (exxo: `agent/run` + `agent.env`; personal: the homelab skill), the repo's command runner, explicit targets, SSH-only git remotes, worktree rules.
- claude-sync edits stay confined to the new agents path; no reformatting of the rest of the script (a concurrent `squad` branch edits `shared_skills()`).
- claude-sync is only ever run with `--diff` against the real contexts; the apply path is exercised only under a fake `$HOME` in tests.
- Never print secret values; the scanner already redacts token-like strings.
- Scanner: stdlib only, runs under `python3 -I`.

## Review Focus

- A real (non-symlink) agent file hand-created in `~/.claude-exxo/agents/` must be adopted into the repo, not deleted — test `adopts unmanaged real agent file` in Task 2.
- A broken or stale (non-shared / wrong-target) symlink in a curated agents dir must be pruned — test `prunes stale and broken links` in Task 2.
- `--diff` must change nothing on disk, including not creating an `agents/` dir — test `diff is read-only` in Task 2.
- Re-running sync must be a no-op — test `second run is idempotent` in Task 2.
- `--compare` against a baseline missing a metric/type (new agent types appear after round one) must report it as new, not crash — test `test_compare_handles_new_types` in Task 4.

---

### Task 1: Agent definitions

**Files:**
- Create: `files/claude/agents/{implementer,reviewer,git-pr-ops,investigator,sanity-cms,notion-ops}.md`
- Test: `tests/claude-agents-lint.sh`

**Interfaces:**
- Produces: the six agent files, consumed by Task 2's `shared_agents()`.

- [ ] **Step 1: Write the failing lint test** — for every `files/claude/agents/*.md`: frontmatter starts at line 1; `name:` equals basename without `.md`; `description:` non-empty; `model:` in `sonnet|opus|haiku|inherit`; body contains a `## Environment` heading and the strings `run-with-secrets`, `SSH`, `worktree`. Also asserts all six expected names exist.
- [ ] **Step 2: Run** `bash tests/claude-agents-lint.sh` — expected FAIL (no agents dir).
- [ ] **Step 3: Write the six agents.** Shared `## Environment` block (secrets, command runner, explicit targets, SSH remotes, worktrees, approvals/prompts), then a per-agent `## Procedure` and `## Report` section. Per spec §4.1: implementer = read plan/task, TDD per repo convention, commit, report diff summary; reviewer = confidence-filtered findings, no fixes unless asked; git-pr-ops = mechanical, uses `worktree-closedown`; investigator = scrollback stays with the agent, returns cause + evidence; sanity-cms = loads Sanity rules (`list_sanity_rules`/`get_sanity_rules`) and `mantine-docs` when touching UI; notion-ops = the one place Notion tooling loads, prefers the `claude_ai_Notion` connector.
- [ ] **Step 4: Run** lint — expected PASS.
- [ ] **Step 5: Commit.**

### Task 2: claude-sync agents delivery path

**Files:**
- Modify: `scripts/claude-sync` (new `SRC_AGENTS` var; new functions after `is_cc_managed()`; one line in the `--diff` loop; one line in the apply loop)
- Test: `tests/claude-sync-agents.sh`

**Interfaces:**
- Consumes: `files/claude/agents/*.md` (Task 1).
- Produces: `shared_agents()` (heredoc list of names, no `.md`), `is_shared_agent <name>`, `sync_agents_wholedir <ctx>`, `sync_agents_curated <account> <ctx>`, `sync_agents <name> <account> <ctx>`, `agents_status_lines <name> <ctx>` (read-only, for `--diff`).

- [ ] **Step 1: Write the failing test.** Copies `scripts/claude-sync` and `files/claude` into a temp repo, creates a fake `$HOME` with `.claude-personal`, `.claude-exxo`, `.claude-exxo-personal`, adds a non-shared `private-probe.md` agent to the temp repo, then asserts:
  - `diff is read-only`: `HOME=$fake claude-sync --diff` prints an `agents` section with `implementer.md: missing (would be linked)` for exxo and `agents: would link` for personal, and no `agents` dir exists afterwards.
  - personal `agents` is a symlink to `$repo/files/claude/agents`.
  - exxo and exxo-personal `agents` are real dirs holding exactly the six `<name>.md` symlinks to the repo files; `private-probe.md` absent.
  - `prunes stale and broken links`: a pre-seeded `private-probe.md` link and a dangling `gone.md` link in exxo are removed.
  - `adopts unmanaged real agent file`: a real `handmade.md` in exxo ends up at `$repo/files/claude/agents/handmade.md` and is gone from the context.
  - `second run is idempotent`: second apply prints `agents: already linked` for personal and leaves the exxo dir listing unchanged.
- [ ] **Step 2: Run** `bash tests/claude-sync-agents.sh` — expected FAIL.
- [ ] **Step 3: Implement** the functions as line-for-line mirrors of the skills functions (entries are files, not dirs; links named `<name>.md`); `sync_agents` dispatches personal → wholedir, others → curated; `agents_status_lines` reports per shared agent `current | missing (would be linked) | wrong target (would be relinked)` plus `would prune:` and `unmanaged, would adopt:` lists, personal: `already linked | would link -> <path>`.
- [ ] **Step 4: Run** test — expected PASS; also `bash -n scripts/claude-sync`.
- [ ] **Step 5: Commit.**

### Task 3: Delegation policy, plugins, docs

**Files:**
- Modify: `files/claude/CLAUDE.md.shared` (the "Orchestrator/subagent model policy" section only)
- Modify: `files/claude/settings.shared.json` (`enabledPlugins`)
- Modify: `files/claude/README.md`, `files/claude/skills/claude-workstation-setup/SKILL.md` (new agents section + plugin lazy-load note)

- [ ] **Step 1: Policy text** per spec §4.2: dedicated agent first; `general-purpose` is the fallback and its roster line says why; omit `model` for dedicated agents (definition pins it), pass `opus` only with a one-line reason; self-audit extended to general-purpose launches for implement/review/git/investigate/Sanity/Notion-shaped tasks.
- [ ] **Step 2: Plugins** per spec §4.3: set `notion@claude-plugins-official` and `vercel@claude-plugins-official` to `false` (explicit `false`, not deletion — the merged file is copied over the live one, and an absent key would leave an installed marketplace plugin at its default, which is on). Keep `linear@claude-plugins-official`: the parentedit repo's `linear-tpe` skill hard-codes `mcp__plugin_linear_linear__*` tool names. Figma: no Figma plugin is in any fragment or installed in any context, so nothing to disable.
- [ ] **Step 3: Verify** `jq -e '.enabledPlugins["notion@claude-plugins-official"] == false and .enabledPlugins["vercel@claude-plugins-official"] == false and .enabledPlugins["linear@claude-plugins-official"] == true' files/claude/settings.shared.json` and `jq -s '.[0] * .[1]' settings.shared.json settings.exxo.json` still parses.
- [ ] **Step 4: Docs** — README + skill: agents delivery path, `shared_agents()`, plugin lazy-load (`/plugin` enable for the session; the next `claude-sync` reverts it), `claude mcp remove -s user notion` per context.
- [ ] **Step 5: Commit** (policy + plugins + docs as separate commits).

### Task 4: `scripts/claude-usage-scan`

**Files:**
- Create: `scripts/claude-usage-scan` (from the scratchpad `transcript_scan.py`; shebang `#!/usr/bin/env -S python3 -I`)
- Test: `tests/test_claude_usage_scan.py` (unittest, subprocess, synthetic transcripts in a temp dir)

**Interfaces:**
- Produces: `out["periods"][p]["headline"]` = `{agent_calls, gp_calls, gp_call_share_pct, sub_tokens, gp_sub_tokens, gp_token_share_pct, sub_tokens_by_type: {type: int}}`; CLI `--compare BASE.json [--current CUR.json]`, text by default, JSON with `--json`.

- [ ] **Step 1: Failing tests:** `test_headline_gp_share` (fixture: one GP subagent with weighted tokens 100 and one `reviewer` with 300 → `gp_token_share_pct == 25.0`, `gp_calls == 1`, `agent_calls == 2`); `test_compare_text` (base vs current files → output contains `gp_token_share_pct` with both values and a signed delta); `test_compare_handles_new_types` (type present only in current → reported `new`).
- [ ] **Step 2: Run** `python3 -I tests/test_claude_usage_scan.py` — FAIL.
- [ ] **Step 3: Implement** `headline(period_out) -> dict` and `compare(base, cur) -> dict` + `print_compare(cmp)`; GP types are `general-purpose` and `(default)`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit.**

### Task 5: Baseline

- [ ] **Step 1:** `scripts/claude-usage-scan --json --aggregate-only > docs/superpowers/specs/2026-10-23-usage-baseline.json` (aggregate-only added during execution: the repo is public, so no task descriptions, project names or UUID server names); check it with `grep -cE 'sk-|ghp_|xox|AKIA|eyJ' ` → 0 hits outside `<redacted>`.
- [ ] **Step 2:** `scripts/claude-usage-scan --compare docs/superpowers/specs/2026-10-23-usage-baseline.json --current docs/superpowers/specs/2026-10-23-usage-baseline.json` shows zero deltas.
- [ ] **Step 3: Commit;** add the 30-day re-run (2026-11-22) to the spec backlog.

### Task 6: Verify and publish

- [ ] **Step 1:** from the worktree, `scripts/claude-sync --diff` — expect per context: settings diff with notion/vercel → `false`; CLAUDE.md diff in the policy section; agents: personal `would link`, exxo and exxo-personal six `missing (would be linked)`.
- [ ] **Step 2:** push the branch once; `gh pr create --draft` with the diff summary (names only), linear finding, and manual follow-ups.
