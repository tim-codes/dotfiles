# ux-designer peer session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From a builder session, `/ux-designer start <target-url> <scope>` opens an opus UX/UI designer as a peer Claude session in a sibling tmux window. The designer handshakes back, critiques the UI, drafts on a Claude Design canvas, does one review pass, and at wrap-up records the result in Figma. It never writes app code.

**Architecture:** Five pieces. (1) `claude-kickoff` gains optional `agent:`/`name:` frontmatter keys, mapped to `claude --agent`/`--name`, and `model:` becomes optional when `agent:` is set. (2) A personal-only agent definition `files/claude/agents/ux-designer.md` with a `tools:` allowlist. (3) A small launcher `scripts/ux-designer-peer` (`start` writes the brief and opens the tmux window, `stop` closes a window by id only), with a hermetic test. (4) A personal-only skill `files/claude/skills/ux-designer/` holding the builder-side protocol and the brief template. (5) `exxo-common@exxo-skills` enabled in every context through the settings fragments. An operator-run trial launch then verifies the tools and the model, and adjusts the allowlist.

**Tech Stack:** bash (`set -uo pipefail`, house style of `scripts/claude-kickoff`), yq v4, jq, tmux, Claude Code 2.1.317 (`--agent <agent>`, `-n/--name <name>` checked against `claude --help`), shell test scripts under `tests/` (no justfile in this repo; each test runs as `bash tests/<name>.sh`).

**Spec:** `docs/superpowers/specs/2026-11-03-ux-designer-peer-design.md`

## Global Constraints

- Experimental and personal-only: `ux-designer` is NOT added to `shared_agents()` (`scripts/claude-sync:274-284`) or `shared_skills()` (`scripts/claude-sync:237-252`), and NOT to the global roster in `files/claude/CLAUDE.md.shared`. No product-repo or squad-repo changes.
- Generic: no app, repo, port or stack is named in the agent, skill, brief template or helper, except on a line labelled as an example (`e.g.` or `Example`).
- The designer never writes app code, tests or repo config. Its only writes go to a scratch directory.
- `model: opus` by default (Tim's decision 2026-11-03). An explicit `model:` in the brief wins over the agent's pin. Use a lighter model only when Tim asks.
- Builder and designer share one context (native `SendMessage` cannot cross contexts) and one permission mode.
- The designer's tmux window is targeted by window **id** (`@N`), never by name, and never the session. Nothing in this work runs `tmux kill-session`.
- The designer starts no OAuth flow or dialog. Sign-in gaps are reported at handshake, and the builder raises them with Tim.
- Figma is written only at wrap-up, only into the file Tim names, and never into a client snapshot.
- One automatic review pass: the designer reviews the build once, the builder iterates once, then Tim reviews. Enforced by instructions only.
- Edit source fragments (`files/claude/settings.*.json`), never deployed `~/.claude-*/settings.json`.
- Secrets: none involved. If one appears, reference it and never write it.
- Git: work on `feat/ux-designer-peer` in `/Users/tim/dev/dotfiles-feat-ux-designer-peer`. Commit each task. End every commit message with the two attribution lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3`
  Do not push unless told.

## Review Focus

1. **A scope string with shell or markdown metacharacters** (quotes, `$HOME`, backticks, `&`, `\1`, a line that is exactly `---`). The brief body must carry it verbatim, the frontmatter must be unaffected, and the window name and session name must not change. Test: Task 3 `scope_metacharacters_survive`.
2. **`/ux-designer start` run outside tmux, or with no resolvable context.** The skill should refuse with a clear message and open nothing, not start a designer in some other session or context. Test: Task 3 `refuses_outside_tmux` and `refuses_without_context`.
3. **`stop` given a session name, window name or empty argument.** It must refuse and run no tmux command; only `@<digits>` is accepted. Test: Task 3 `stop_refuses_non_window_id`.
4. **A brief with `agent:` but no `model:`/`effort:`, or with a malformed `agent:` value.** A missing model is fine (the agent's own model applies and no `--model` is passed). A missing effort is still exit 4. A malformed agent value is exit 5 and launches nothing. A `name:` with spaces travels as one argv entry. Test: Task 1 `agent_without_model_omits_model_flag`, `agent_without_effort_exits_4`, `bad_agent_value_exits_5`, `name_with_spaces_is_one_arg`.
5. **A second `/ux-designer start` while a designer window already exists.** Window names collide (`ux-designer`), so `stop` must still close only the recorded id. Covered by targeting ids only, which Test 3 `stop_refuses_non_window_id` and `stop_kills_by_id` pin. The skill tells the builder to keep the `@N` it recorded.

---

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/claude-kickoff` (modify) | `agent`/`name` keys, optional model with `agent:` |
| `tests/claude-kickoff.sh` (modify) | tests for the new keys |
| `src/claude/prompts/_template.md` (modify) | documents `agent`/`name` |
| `files/claude/settings.shared.json` (modify) | `exxo-common@exxo-skills` + `exxo-skills` marketplace for every context |
| `files/claude/settings.exxo.json` (modify) | keeps only `exxo-mantine@exxo-skills` and the Exxo grants |
| `tests/claude-sync-permissions.sh`, `tests/claude-sync-reserve.sh` (modify) | flip the "personal never gets the marketplace" assertions |
| `files/claude/agents/ux-designer.md` (create) | designer agent definition |
| `tests/claude-agents-lint.sh`, `tests/claude-sync-agents.sh` (modify) | agent content checks; ux-designer stays personal-only |
| `scripts/ux-designer-peer` (create), `src/bin/ux-designer-peer` (symlink), `.gitignore` (negation) | `start` / `stop` launcher |
| `tests/ux-designer-peer.sh` (create) | hermetic launcher test (stub `tmux`, stub `claude-kickoff`) |
| `files/claude/skills/ux-designer/SKILL.md`, `brief-template.md` (create) | builder-side protocol; brief body template |
| `tests/claude-skills-lint.sh` (modify) | skill content and personal-only checks |
| `CLAUDE.md`, `files/claude/README.md`, `files/claude/skills/claude-workstation-setup/SKILL.md`, `scripts/claude-sync` header comment (modify) | docs |

---

### Task 1: claude-kickoff `agent` and `name` keys

**Files:**
- Modify: `scripts/claude-kickoff` (usage text ~66-110; `fm_get` reads ~392-405; required-key checks ~418-420; dry-run block ~578-618; both `exec` lines ~632-635)
- Modify: `src/claude/prompts/_template.md` (key list in the comment block)
- Modify: `CLAUDE.md` (the `claude-kickoff` line under Maintenance)
- Test: `tests/claude-kickoff.sh`

**Interfaces:**
- Produces: frontmatter `agent: <name>` → argv `--agent <name>`, and `name: <text>` → argv `--name <text>`, on new launches only. With `agent:` set, `model:` may be omitted, and then no `--model` is passed (new or resume). Dry-run prints `agent: <a|none>` and `name: <n|none>` immediately after the `deny:` line, and `model: none (agent default)` when the model is omitted. Task 3 relies on these keys and the exit codes.

Decisions fixed here:
- Variable names `session_agent` / `session_name`. `agent` is already the tmux-marker variable (`scripts/claude-kickoff:557-558`, the context's `agent` key), so do not reuse it.
- `agent` = the first word of the value, which must match `^[A-Za-z0-9][A-Za-z0-9_:-]*$` (plugin agents carry `:`); otherwise `die 5 "invalid agent '<v>' ..."`. `name` = the whole trimmed value. Neither key is checked against the agent files (plugin agents live elsewhere; the trial covers resolution).
- Argv order on a new launch: `add_dir_args`, `member_deny_args`, `deny_args`, then `--agent A`, then `--name N`, then `--model M` (if any), `--effort E`, body. The `--add-dir` flags stay first because the option is variadic (comment at `scripts/claude-kickoff:633-634`). Build a `model_args=()` array used by both exec lines.
- On `--resume`, `agent`/`name` are not passed (the resumed session keeps what it had). The model is still optional there when `agent:` is set.
- The tmux marker already handles an empty model (`marker_model` empty → `@agent_model` unset); leave it.
- The missing-key message and exit 4 for `model` stay when there is no `agent:`. The usage text's exit-4 line becomes "cwd, context, effort, or model when no agent is set".

- [ ] **Step 1: Write the failing tests** (append to `tests/claude-kickoff.sh` after the `deny` block, around line 329; same `kick`/`check`/`expect_rc` helpers)

```bash
# agent / name: --agent and --name before --model; model optional with agent
sed 's|^model: .*|&\nagent: ux-designer\nname: ux-designer-nav|' "$T/fixture.md" >"$T/agent.md"
kick "$T/agent.md" --dry-run
check "agent_and_name_echoed" bash -c 'printf "%s\n" "$1" | grep -qx "agent: ux-designer" && printf "%s\n" "$1" | grep -qx "name: ux-designer-nav"' _ "$out"
check "agent_name_lines_follow_deny" bash -c 'printf "%s\n" "$1" | grep -oE "^(deny|agent|name):" | tr "\n" " " | grep -qx "deny: agent: name: "' _ "$out"
kick "$T/fixture.md" --dry-run
check "agent_name_default_none" bash -c 'printf "%s\n" "$1" | grep -qx "agent: none" && printf "%s\n" "$1" | grep -qx "name: none"' _ "$out"
kick "$T/agent.md" --no-member-deny
check "agent_name_argv_before_model" bash -c '[ "$(sed -n 1,9p "$1" | tr "\n" " ")" = "argc=9 arg<--agent> arg<ux-designer> arg<--name> arg<ux-designer-nav> arg<--model> arg<opus> arg<--effort> arg<high> " ]' _ "$REC"
grep -v '^model:' "$T/agent.md" >"$T/agent-nomodel.md"
kick "$T/agent-nomodel.md" --dry-run
check "agent_without_model_dry_run" bash -c '[ "$2" -eq 0 ] && printf "%s\n" "$1" | grep -qx "model: none (agent default)"' _ "$out" "$rc"
kick "$T/agent-nomodel.md" --no-member-deny
check "agent_without_model_omits_model_flag" bash -c '! grep -qx "arg<--model>" "$1" && grep -qx "arg<--agent>" "$1" && grep -qx "arg<--effort>" "$1"' _ "$REC"
grep -v '^effort:' "$T/agent-nomodel.md" >"$T/agent-noeffort.md"
expect_rc "agent_without_effort_exits_4" 4 "$T/agent-noeffort.md" --dry-run
sed 's|^agent: .*|agent: ux;designer|' "$T/agent.md" >"$T/badagent.md"
expect_rc "bad_agent_value_exits_5" 5 "$T/badagent.md" --dry-run
sed 's|^name: .*|name: ux designer nav|' "$T/agent.md" >"$T/spacename.md"
kick "$T/spacename.md" --no-member-deny
check "name_with_spaces_is_one_arg" grep -qx "arg<ux designer nav>" "$REC"
kick "$T/agent-nomodel.md" --resume sess-a --account exxo --cwd "$W" --no-member-deny
check "resume_with_agent_passes_no_agent_name_or_model" bash -c '! grep -qxE "arg<--(agent|name|model)>" "$1" && grep -qx "arg<--resume>" "$1"' _ "$REC"
expect_rc "missing_model_without_agent_still_exits_4" 4 "$T/no-model.md" --dry-run
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-kickoff.sh 2>&1 | grep -E '^FAIL' `
Expected: FAIL lines for `agent_and_name_echoed`, `agent_name_argv_before_model`, `agent_without_model_*`, `bad_agent_value_exits_5` (and the others above). No pre-existing case fails.

- [ ] **Step 3: Implement in `scripts/claude-kickoff`**

Read `session_agent=$(fm_get agent | first_word)` and `session_name=$(fm_get name)` next to the other `fm_get` calls. Relax the model check to `[ -n "$model" ] || [ -n "$session_agent" ] || die 4 ...`. Validate the agent charset (exit 5) in the "harness, role, lifetime" block. Build `agent_args=()` (`--agent`, then `--name` when set) and `model_args=()` (empty when no model). Add the two dry-run lines after `deny:`, and print `model: none (agent default)` when the model is empty. Use `"${agent_args[@]+...}"` and `"${model_args[@]+...}"` in the new-launch exec, and only `model_args` in the resume exec. Document both keys in `usage()` under "Optional keys, all echoed by --dry-run", plus the relaxed exit-4 wording.

- [ ] **Step 4: Run to verify it passes**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-kickoff.sh 2>&1 | tail -3; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-kickoff-member-deny.sh | tail -1; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-kickoff-trust.sh | tail -1; shellcheck /Users/tim/dev/dotfiles-feat-ux-designer-peer/scripts/claude-kickoff`
Expected: no `FAIL:` lines in any of the three test scripts, and shellcheck prints nothing. The member-deny exact-argv checks (`tests/claude-kickoff-member-deny.sh:80-92`) still pass, because a brief without `agent:` gets unchanged argv.

- [ ] **Step 5: Docs.** In `src/claude/prompts/_template.md`, add `agent` and `name` to the key list ("optional: `agent` → `--agent` (a subagent definition run as the main session; `model` may then be omitted), `name` → `--name` (display / ListAgents name)"). In `CLAUDE.md`, change the `claude-kickoff` line's "frontmatter `cwd/context/model/effort`" to add "optional `agent`/`name` → `--agent`/`--name`".

- [ ] **Step 6: Commit**

```bash
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer add scripts/claude-kickoff tests/claude-kickoff.sh src/claude/prompts/_template.md CLAUDE.md
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer commit -m "claude-kickoff: agent and name frontmatter keys (--agent/--name); model optional with agent" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3"
```

---

### Task 2: Enable exxo-common in every context

**Files:**
- Modify: `files/claude/settings.shared.json` (`enabledPlugins` ~400-414, `extraKnownMarketplaces` ~415-427)
- Modify: `files/claude/settings.exxo.json:1-13`
- Modify: `tests/claude-sync-permissions.sh:76-77`, `tests/claude-sync-reserve.sh:38-39`
- Modify: `files/claude/README.md` (the `settings.exxo.json` bullet and the "must never get it" paragraph, ~10-29)
- Modify: `files/claude/skills/claude-workstation-setup/SKILL.md` (~88-89, plugin path 2 at ~300-311, the run-with-secrets paragraph ~313-324, the one-path rule ~338-347)
- Modify: `scripts/claude-sync` header comment (~19-24, ~83-87). Comment only, no logic change.

**Interfaces:**
- Produces: every context's merged `settings.json` has `.enabledPlugins["exxo-common@exxo-skills"] == true` and `.extraKnownMarketplaces["exxo-skills"]` (SSH source `git@github.com:Exxo-Labs/skills.git`). Only the exxo-fragment contexts (exxo, exxo-personal, exxo-openrouter) have `exxo-mantine@exxo-skills`. Tasks 4 and 5 point at `exxo-common:claude-design-workflow`, `exxo-common:working-with-figma` and `exxo-common:agent-chrome-screenshots` (plugin skills are namespaced).

Grounding: exxo, exxo-personal and exxo-openrouter already get exxo-common from `settings.exxo.json:3` (`CONTEXTS` at `scripts/claude-sync:158` maps all three to the exxo fragment, and the openrouter overlay does not disable it). So the effective change is personal and reserve. Moving the plugin and marketplace into the shared fragment states "all contexts" once.

- [ ] **Step 1: Collision check (record the result in the commit message)**

Run: `comm -12 <(ls ~/dev/exxo/skills/common/skills | sort) <(ls /Users/tim/dev/dotfiles-feat-ux-designer-peer/files/claude/skills | sort)`
Expected: exactly `run-with-secrets`. Check exxo-common for agents too: `ls ~/dev/exxo/skills/common/agents 2>/dev/null` should print nothing. If the list has any other name, stop and report it.
Decision for `run-with-secrets` (Claude's call, after Tim accepted exxo-common everywhere on 2026-11-03, superseding ENG-20): both copies coexist in personal/reserve (plugin copy `exxo-common:run-with-secrets`, repo copy bare `run-with-secrets`), and their descriptions are made mutually exclusive so a session can't pick the wrong credential guidance (the 2026-08-18 failure):
- In this branch, `files/claude/skills/run-with-secrets/SKILL.md` description gains "Homelab repo only (zima/ragnar, onepassword lookups); NOT for Exxo repos, which use exxo-common:run-with-secrets." Keep it within the repo's description limits; `tests/claude-skills-lint.sh` must pass.
- In Exxo-Labs/skills, a separate small PR (own worktree via `wt -C ~/dev/exxo/skills switch --create fix/run-with-secrets-scope --base origin/main --no-cd -y`, gate `scripts/verify.sh` + `scripts/format.sh --check`, draft PR, do not merge) makes `common/skills/run-with-secrets/SKILL.md`'s description say "Exxo repos only (agent/run, agent.env); NOT for the homelab repo, which has its own run-with-secrets." ≤400 chars, single-quoted, starts "Use when". No rename (renames break consumers).
- The agents' Environment block (`files/claude/agents/implementer.md:16-24`) already picks per context; unchanged.

- [ ] **Step 2: Flip the tests first**

In `tests/claude-sync-permissions.sh`, replace the check at lines 76-77 with:

```bash
check "personal gets the exxo-skills marketplace" \
    jq -e '.extraKnownMarketplaces["exxo-skills"].source.url == "git@github.com:Exxo-Labs/skills.git"' "$FAKE/.claude-personal/settings.json"
check "personal enables exxo-common" jq -e '.enabledPlugins["exxo-common@exxo-skills"] == true' "$FAKE/.claude-personal/settings.json"
check "personal never gets exxo-mantine" jq -e '.enabledPlugins | has("exxo-mantine@exxo-skills") | not' "$FAKE/.claude-personal/settings.json"
for ctx in exxo exxo-personal; do
    check "$ctx still enables exxo-common and exxo-mantine" \
        jq -e '.enabledPlugins["exxo-common@exxo-skills"] and .enabledPlugins["exxo-mantine@exxo-skills"]' "$FAKE/.claude-$ctx/settings.json"
done
```

In `tests/claude-sync-reserve.sh`, replace lines 38-39 with `check "reserve settings carry the exxo marketplace and exxo-common, not exxo-mantine"`, using `jq -e '(.extraKnownMarketplaces | has("exxo-skills")) and .enabledPlugins["exxo-common@exxo-skills"] and (.enabledPlugins | has("exxo-mantine@exxo-skills") | not)'` on `$R/settings.json`. Keep the existing `$ctx settings carry exxo marketplace` loop at line 71, and add `exxo-openrouter enables exxo-common` to it.

- [ ] **Step 3: Run to verify it fails**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-sync-permissions.sh | grep FAIL; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-sync-reserve.sh | grep FAIL`
Expected: FAIL on the personal and reserve marketplace / exxo-common checks only.

- [ ] **Step 4: Move the keys.** Add `"exxo-common@exxo-skills": true` to `settings.shared.json` `enabledPlugins`, and the `exxo-skills` block (byte-identical to `settings.exxo.json:7-12`) to its `extraKnownMarketplaces`. From `settings.exxo.json`, remove `exxo-common` and the `extraKnownMarketplaces` block, keeping `"enabledPlugins": {"exxo-mantine@exxo-skills": true}` and the permissions.

- [ ] **Step 5: Run to verify it passes**

Run: `for t in claude-sync-permissions claude-sync-reserve claude-sync-agents claude-sync-openrouter claude-sync-local-settings claude-sync-prefs claude-sync-mcp claude-sync-args; do bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/$t.sh >/tmp/x 2>&1 || { echo "FAIL $t"; grep FAIL /tmp/x; }; done`
Expected: no output.

- [ ] **Step 6: Docs.** `files/claude/README.md`: the `settings.exxo.json` bullet now says "enables `exxo-mantine@exxo-skills` and adds the Exxo read-only cloud grants". Add a bullet saying `settings.shared.json` enables `exxo-common@exxo-skills` and registers `exxo-skills` in every context (Tim, 2026-11-03, for `claude-design-workflow`/`working-with-figma` in personal). Replace "`~/.claude-personal` must never get it (homelab #76, Linear ENG-20)" with a line saying the split now holds only for `exxo-mantine` and the Exxo grants, and that exxo-common was widened on 2026-11-03. Make the matching edits in `claude-workstation-setup/SKILL.md`. Path 2 becomes "every context enables exxo-common; exxo also enables exxo-mantine". The run-with-secrets paragraph gets: "Since 2026-11-03 personal and reserve also load `exxo-common:run-with-secrets` beside the homelab copy; the descriptions are disjoint and the agents' Environment block names the right one per context." The "personal must never depend on a private Exxo repo" sentence is narrowed to the mantine skills. Personal and reserve still need `claude plugin install exxo-common@exxo-skills` under each `CLAUDE_CONFIG_DIR` once (plugin installs are snapshots); note that. Update the `scripts/claude-sync` header comment the same way (comment lines only).

- [ ] **Step 7: Commit**

```bash
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer add files/claude/settings.shared.json files/claude/settings.exxo.json tests/claude-sync-permissions.sh tests/claude-sync-reserve.sh files/claude/README.md files/claude/skills/claude-workstation-setup/SKILL.md scripts/claude-sync
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer commit -m "claude-sync: enable exxo-common in every context" -m "Collision check: only run-with-secrets (coexists namespaced; descriptions made mutually exclusive here and in Exxo-Labs/skills). exxo-mantine stays exxo-only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3"
```

---

### Task 3: `ux-designer-peer` launcher (start / stop)

**Files:**
- Create: `scripts/ux-designer-peer` (executable)
- Create: `src/bin/ux-designer-peer` → `../../scripts/ux-designer-peer` (symlink, as `src/bin/claude-kickoff`)
- Modify: `.gitignore` (add `!src/bin/ux-designer-peer` beside `!src/bin/claude-kickoff`, line 15)
- Test: `tests/ux-designer-peer.sh`
- Consumes the template from Task 4 (`files/claude/skills/ux-designer/brief-template.md`). The test creates its own minimal template via `UX_DESIGNER_TEMPLATE`, so this task does not depend on Task 4's wording.

**Interfaces:**
- Consumes: Task 1's `agent:`/`name:` keys and `claude-kickoff <brief> --dry-run` exit codes.
- Produces (Task 4's skill calls exactly these):

```
ux-designer-peer start --target <http(s)-url> --scope <text> --builder <ListAgents name>
                       [--cwd DIR] [--context CTX] [--session S] [--model M] [--effort E]
                       [--short SLUG] [--brief-dir DIR] [--dry-run]
ux-designer-peer stop <@window-id>
```

`start` writes the brief, validates it with `claude-kickoff <brief> --dry-run`, then runs
`tmux new-window -d -P -F '#{window_id}' -t <session>: -n ux-designer -c <cwd> "claude-kickoff <quoted brief path>"`.
On stdout it prints exactly three `key: value` lines: `brief: <path>`, `name: ux-designer-<short>`, `window: @N`. With `--dry-run` it prints the same lines, except that `window:` is replaced by `tmux: <the command line it would run>`; it writes the brief and runs the kickoff dry-run, but runs no tmux command. `stop @N` runs `tmux kill-window -t @N` and prints `closed: @N`.

Fixed values:
- Defaults: `--cwd` = `git -C "$PWD" rev-parse --show-toplevel`, else `$PWD`. `--context` = basename of `$CLAUDE_CONFIG_DIR` with the `.claude-` prefix stripped. `--session` = `tmux display-message -p '#S'` (requires `$TMUX`). `--model opus`, `--effort high`. `--brief-dir "${XDG_STATE_HOME:-$HOME/.local/state}/ux-designer"`. `--short` = slug of the scope: lowercase, runs of non-`[a-z0-9]` become `-`, trimmed, cut to 24 characters, then a trailing `-` stripped; `scope` if empty. The template path defaults to `<repo>/files/claude/skills/ux-designer/brief-template.md`, found through the script's real path (same symlink walk as `scripts/claude-kickoff:510-515`), with `UX_DESIGNER_TEMPLATE` overriding it.
- Brief file: `<brief-dir>/<YYmmdd-HHMMSS>-<short>.md`. Frontmatter lines, in order: `---`, `cwd: <cwd>`, `context: <ctx>`, `model: <m>`, `effort: <e>`, `agent: ux-designer`, `name: ux-designer-<short>`, `---`. The body is the template with `{{SCOPE}}`, `{{TARGET}}`, `{{BUILDER}}`, `{{NAME}}`, `{{CONTEXT}}` substituted. Substitute through `awk` reading values from `ENVIRON` (never sed replacement strings), so metacharacters pass through verbatim. User text goes only in the body.
- Exit codes: 0 ok. 2 usage: unknown option, missing `--target`/`--scope`/`--builder`, a target not matching `^https?://`, or a `stop` argument not matching `^@[0-9]+$`. 3 environment: no `$TMUX` and no `--session`, no context resolvable, template unreadable, `tmux` or `claude-kickoff` not on PATH. 4: `claude-kickoff --dry-run` refused the brief (its stderr is passed through). 5: `tmux new-window` failed or printed no `@N`.

- [ ] **Step 1: Write the failing test `tests/ux-designer-peer.sh`**

Style follows `tests/claude-kickoff.sh`: temp dir and trap, `ok`/`bad`/`check`, and a stub PATH `$BIN:/usr/bin:/bin`. Stub `tmux`: append its argv to `$T/tmux.log`; for `display-message` print `main`; for `new-window` print `@7`. Stub `claude-kickoff`: append its argv to `$T/kick.log` and exit `${KICK_RC:-0}`. Write a template file containing `S={{SCOPE}} T={{TARGET}} B={{BUILDER}} N={{NAME}} C={{CONTEXT}}`, and set `UX_DESIGNER_TEMPLATE` to it. Run each case with `TMUX=x CLAUDE_CONFIG_DIR=$T/.claude-personal`. Cases (test names are the `check` descriptions):

```bash
run start --target http://localhost:3000 --scope 'Nav & density (main screen)' --builder builder-1 --cwd "$T/app" --brief-dir "$T/briefs"
check "start_prints_brief_name_window" bash -c 'printf "%s\n" "$1" | grep -qx "name: ux-designer-nav-density-main-screen" && printf "%s\n" "$1" | grep -qx "window: @7" && printf "%s\n" "$1" | grep -q "^brief: $2/briefs/[0-9]\{6\}-[0-9]\{6\}-nav-density-main-screen\.md$"' _ "$out" "$T"
brief=$(printf '%s\n' "$out" | sed -n 's/^brief: //p')
check "brief_frontmatter_exact" test "$(sed -n 1,8p "$brief" | tr '\n' '|')" = "---|cwd: $T/app|context: personal|model: opus|effort: high|agent: ux-designer|name: ux-designer-nav-density-main-screen|---|"
check "brief_body_substituted" grep -qxF "S=Nav & density (main screen) T=http://localhost:3000 B=builder-1 N=ux-designer-nav-density-main-screen C=personal" "$brief"
check "kickoff_dry_run_validated_brief" grep -qxF "$brief --dry-run" "$T/kick.log"
check "tmux_new_window_argv" grep -qxF "new-window -d -P -F #{window_id} -t main: -n ux-designer -c $T/app claude-kickoff $brief" "$T/tmux.log"
# scope_metacharacters_survive: scope = $'a "q" $HOME `x` & \\1\n---\nz'
#   → body contains that scope verbatim (compare with a heredoc'd expected file); frontmatter lines 1-8 unchanged in shape; short slug = a-q-home-x-1-z
# model_override: --model sonnet --effort low → frontmatter "model: sonnet", "effort: low"
# context_flag_wins: --context reserve with CLAUDE_CONFIG_DIR=.claude-personal → "context: reserve"
# refuses_outside_tmux: TMUX unset, no --session → exit 3, tmux.log has no new-window, no brief written
# session_flag_outside_tmux: TMUX unset, --session work → exit 0, new-window targets "-t work:"
# refuses_without_context: CLAUDE_CONFIG_DIR unset, no --context → exit 3
# refuses_bad_target: --target localhost:3000 → exit 2
# missing_builder_exits_2
# kickoff_refusal_exits_4: KICK_RC=4 → exit 4, no new-window in tmux.log
# dry_run_runs_no_tmux_new_window: --dry-run → exit 0, output has "tmux: " line, tmux.log has no new-window
# stop_kills_by_id: stop @7 → exit 0, tmux.log last line "kill-window -t @7", out "closed: @7"
# stop_refuses_non_window_id: for a in main ux-designer '' '@7;x' 'main:1' → exit 2 and tmux.log unchanged
# never_kill_session: ! grep -q kill-session "$SRC_REPO/scripts/ux-designer-peer"
```

Spell out each commented case as `run …` plus `check`/`expect_rc`, in the same shape as the first block.

- [ ] **Step 2: Run to verify it fails**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/ux-designer-peer.sh`
Expected: FAIL on every case (the script does not exist yet).

- [ ] **Step 3: Implement `scripts/ux-designer-peer`** to the interface above. Give it a header comment and a `usage()` in the style of `scripts/claude-kickoff:1-60`, describing the contract and the exit codes, and `set -uo pipefail`. Create the symlink and the `.gitignore` negation.

- [ ] **Step 4: Run to verify it passes**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/ux-designer-peer.sh | grep -c FAIL; shellcheck /Users/tim/dev/dotfiles-feat-ux-designer-peer/scripts/ux-designer-peer`
Expected: `0`, and no shellcheck output.

- [ ] **Step 5: Commit**

```bash
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer add scripts/ux-designer-peer src/bin/ux-designer-peer .gitignore tests/ux-designer-peer.sh
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer commit -m "ux-designer-peer: start/stop launcher for the designer peer window" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3"
```

---

### Task 4: `ux-designer` skill and brief template

**Files:**
- Create: `files/claude/skills/ux-designer/SKILL.md`
- Create: `files/claude/skills/ux-designer/brief-template.md`
- Modify: `tests/claude-skills-lint.sh` (new section before the final summary, ~line 160)
- Modify: `CLAUDE.md` (one Maintenance line for `ux-designer-peer`, marked experimental)

**Interfaces:**
- Consumes: Task 3's CLI and stdout lines (`brief:`, `name:`, `window:`); Task 5's agent name `ux-designer` and its handshake format (below).
- Produces: `/ux-designer start <target-url> <scope>` and `/ux-designer stop`.

Handshake format (shared with Task 5; both files state it identically). The first line is `ux-designer ready: <its name>`. It is followed by lines `scope: …`, `model: <exact model id>`, `playwright: yes|no`, `design canvas: yes|no`, `figma: signed in|not signed in|unreachable`, and `missing: …` (or `missing: none`).

SKILL.md frontmatter: `name: ux-designer`. `description:` is one line of at most 1024 characters, starts "Experimental:", and names the triggers `/ux-designer start <target-url> <scope>`, `/ux-designer stop` and "a design review or redesign of a running web UI with a designer peer". Body sections (headings exact, since the lint checks them):
- `## Start`. (1) Call `ListAgents` and take this session's own name. (2) Run `ux-designer-peer start --target <url> --scope "<scope>" --builder <name>`, with `--cwd` when the repo is not the cwd. (3) Record the `window: @N` and `name:` lines in the task tracker; the window id is the only handle used later. (4) Wait for the handshake through the native message notification; do not poll. If no handshake arrives within about 5 minutes, check `ListAgents` and `tmux list-windows -F '#{window_id} #{window_name}'`, tell Tim, and do not relaunch blindly. Exit 3 from the helper (not in tmux / no context) is reported to Tim, not worked around. Builder and designer must share context and permission mode.
- `## Handshake`. What to read in it. Reply with anything missing (a preview URL if one exists). If a tool is missing or not signed in, raise it with Tim. If `design canvas: no`, stop the designer (`/ux-designer stop`) and tell Tim.
- `## Round (builder side)`. Read the critique. Wait for Tim's choice (canvas comments or either session). Prototype the chosen direction in the real app on the repo's preview build (the `just preview` convention where the repo has it), then message the designer the preview URL and commit SHA. Large material goes in a hand-off file, not the message.
- `## One review pass`. The designer's feedback arrives once and the builder iterates once. Then both stop, and the builder tells Tim the build is ready for review. A further round starts only on Tim's word. There is no counter; this rule is the guard.
- `## Wrap-up`. Only on Tim's "drafting is final". Tim names the Figma target file and the builder passes it on verbatim. The designer sends Figma links and a closing summary. Then run stop.
- `## Stop`. `ux-designer-peer stop @N`, with the recorded id. Never `kill-session`, never a window name. If the id is lost, `tmux list-windows` and ask Tim which window.
- `## Rules`. Generic: the target, scope and stack come from the arguments and the repo. The squad GUI is named only as `Example:`. The designer is read-only on code. Experimental and personal-only.

`brief-template.md` (the body after the frontmatter, placeholders exactly `{{SCOPE}}`, `{{TARGET}}`, `{{BUILDER}}`, `{{NAME}}`, `{{CONTEXT}}`) says, in order: you are `{{NAME}}`, the ux-designer peer of `{{BUILDER}}` (context `{{CONTEXT}}`); target `{{TARGET}}`; scope `{{SCOPE}}`. The first action is the handshake via `SendMessage` to `{{BUILDER}}`, in the format above. Follow the round protocol in your agent definition: critique → draft on one Claude Design canvas titled with the scope → Tim chooses → the builder prototypes on its preview build → one review pass → stop. Never write in the repo; scratch files go under `${TMPDIR:-/tmp}/ux-designer-{{NAME}}/`.

- [ ] **Step 1: Write the failing lint checks** (append to `tests/claude-skills-lint.sh`, reusing `check`, `contains`, `has_headings`, `is_shared`, `no_context_dirs`)

```bash
# --- ux-designer (experimental, personal-only) -------------------------------
U="$SKILLS/ux-designer/SKILL.md"; UB="$SKILLS/ux-designer/brief-template.md"
generic_only() { ! grep -nE '7797|squad/gui|localhost:[0-9]+|[Mm]antine' "$@" | grep -viE 'e\.g\.|example'; }
check "ux-designer exists" test -f "$U" -a -f "$UB"
check "ux-designer is personal-only" bash -c '! (source <(sed -n "/^shared_skills()/,/^}/p" "$1/scripts/claude-sync"); shared_skills | grep -qx ux-designer)' _ "$REPO_DIR"
check "ux-designer carries the section headings" has_headings "$U" \
    '## Start' '## Handshake' '## Round (builder side)' '## One review pass' '## Wrap-up' '## Stop' '## Rules'
check "ux-designer names the launcher contract" contains "$U" \
    'ux-designer-peer start' 'ux-designer-peer stop @' 'ListAgents' 'window: @N' 'ux-designer ready:' 'kill-session'
check "ux-designer description is marked experimental" sh -c 'case "$1" in Experimental:*) ;; *) exit 1;; esac' _ "$(fm "$U" description)"
check "brief template carries every placeholder" contains "$UB" '{{SCOPE}}' '{{TARGET}}' '{{BUILDER}}' '{{NAME}}' '{{CONTEXT}}' 'SendMessage'
check "ux-designer skill and template are generic" generic_only "$U" "$UB"
check "ux-designer names no context directory" no_context_dirs "$SKILLS/ux-designer"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-skills-lint.sh | grep FAIL`
Expected: FAIL on the ux-designer checks only.

- [ ] **Step 3: Write `SKILL.md` and `brief-template.md`** per the outline above.

- [ ] **Step 4: Run to verify it passes**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-skills-lint.sh | tail -1; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/ux-designer-peer.sh | grep -c FAIL`
Then run `start --dry-run` with the real template: `TMUX=x CLAUDE_CONFIG_DIR=$HOME/.claude-personal /Users/tim/dev/dotfiles-feat-ux-designer-peer/scripts/ux-designer-peer start --target http://localhost:1 --scope probe --builder probe --session none --brief-dir "$TMPDIR/uxd-probe" --dry-run`. That runs the real `claude-kickoff --dry-run`, which is read-only and records nothing.
Expected: `ok: skills lint clean`, `0`, and exit 0 with `brief:`/`name:`/`tmux:` lines. If the real kickoff on PATH is the main checkout's copy and does not know `agent:` yet (Task 1 not merged), put the worktree's `scripts/` first on PATH for this probe: `PATH=/Users/tim/dev/dotfiles-feat-ux-designer-peer/scripts:$PATH`.

- [ ] **Step 5: Docs.** In `CLAUDE.md` under Maintenance, add: "`ux-designer-peer start|stop` - EXPERIMENTAL: opens/closes the ux-designer peer session window for the `ux-designer` skill (personal-only); source `scripts/ux-designer-peer`, on PATH via `src/bin`; test `bash tests/ux-designer-peer.sh`".

- [ ] **Step 6: Commit**

```bash
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer add files/claude/skills/ux-designer tests/claude-skills-lint.sh CLAUDE.md
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer commit -m "ux-designer skill: builder-side protocol and brief template (experimental, personal-only)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3"
```

---

### Task 5: `ux-designer` agent definition

**Files:**
- Create: `files/claude/agents/ux-designer.md`
- Modify: `tests/claude-agents-lint.sh` (ux-designer block before the final summary, line 35)
- Modify: `tests/claude-sync-agents.sh` (personal-only assertion after line 59)
- Modify: `files/claude/skills/claude-workstation-setup/SKILL.md` (subagent section ~356-370: one sentence on the experimental, personal-only `ux-designer`, pinned opus, with a `tools:` allowlist)

**Interfaces:**
- Consumes: the handshake format (Task 4); plugin skill names from Task 2.
- Produces: an agent named `ux-designer`, run as the main session through `claude --agent ux-designer` (Task 1).

Frontmatter (exact):

```
---
name: ux-designer
description: Experimental UX/UI designer peer for any web UI — critiques a running app in a given scope, drafts directions on a Claude Design canvas with handoff specs, reviews the builder's preview once, and records the final artboards in Figma at wrap-up. Never writes app code. Launched as a peer session by the ux-designer skill, not as a subagent.
model: opus
tools: Read, Grep, Glob, Bash, Write, Skill, SendMessage, ListAgents, ToolSearch, Artifact, ArtifactComments, mcp__playwright__browser_navigate, mcp__playwright__browser_navigate_back, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_tabs, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_press_key, mcp__playwright__browser_wait_for, mcp__playwright__browser_console_messages, mcp__playwright__browser_close, mcp__claude_ai_Figma__whoami, mcp__claude_ai_Figma__create_session, mcp__claude_ai_Figma__create_new_file, mcp__claude_ai_Figma__search_design_system, mcp__claude_ai_Figma__get_libraries, mcp__claude_ai_Figma__get_variable_defs, mcp__claude_ai_Figma__use_figma, mcp__claude_ai_Figma__upload_assets, mcp__claude_ai_Figma__get_screenshot, mcp__claude_ai_Figma__get_metadata
---
```

Deliberately left out: `Edit`, `NotebookEdit` and `Agent`. Also left out are the Playwright tools that write data or run code (`browser_type`, `browser_fill_form`, `browser_file_upload`, `browser_select_option`, `browser_evaluate`, `browser_run_code_unsafe`, `browser_drag`, `browser_drop`, `browser_handle_dialog`). The spec's Parts §1 says "no Write/Edit". The spec's later "Settled" section allows Write restricted by instruction to the scratchpad. This plan follows Settled: Write is in, Edit is out. Explicit MCP names follow the parentedit `ui.md` precedent. The Task 6 trial decides whether any are missing.

Body sections, in order:
1. A one-paragraph role.
2. `## Environment`, copied verbatim from `files/claude/agents/implementer.md:12-44`, the block the lint requires.
3. `## Rules`. Read-only on code: never write inside the repo or any git checkout, and never run git commands that change anything. `Write` and Bash output go only under `${TMPDIR:-/tmp}/ux-designer-<your name>/` (screenshots, hand-off files, canvas files; never committed). Read-only on the target app: navigate and read, no form submits, no create/edit/delete actions, because it may be Tim's live instance. Start no sign-in, OAuth or dialog: report the gap at handshake and carry on without it. Never touch tmux sessions or windows. One review pass only.
4. `## Handshake`. The exact format from Task 4, sent with `SendMessage` to the builder named in the brief as the first action. Check reachability first with `ToolSearch` (Playwright, Artifact, ArtifactComments, Figma), `mcp__claude_ai_Figma__whoami` (if it fails or needs auth, say `not signed in` and do not start auth), and `Artifact` quickstart with `intent: "design"` (no Design type → `design canvas: no`, then stop after the handshake).
5. `## Round`. Steps 1-5 from the spec's Round section. Critique with Playwright: the target read-only, scratch screenshots, and the repo's UI code read-only to learn its component library and theme. Use `exxo-common:agent-chrome-screenshots` only when a signed-in page is in scope. Draft on one Claude Design canvas per scope, titled `<scope>`, one artboard per direction (tight scope: one draft, no options), plus a `design:design-handoff` spec per direction. Read Tim's canvas comments with `ArtifactComments`. Review the builder's preview once with `design:design-critique` and `design:accessibility-review`. Approved artboards stay; a changed direction goes on new artboards (the canvas has no version history).
6. `## Wrap-up`. Only on Tim's "drafting is final", relayed by the builder, with the Figma file Tim named. Rebuild the final artboards per `exxo-common:claude-design-workflow` §3, following `exxo-common:working-with-figma` and Figma's own skills (`figma-use` before `use_figma`, `figma-generate-design`). Never write to a file Tim did not name, or to a client snapshot. Send the builder the links and a closing summary.
7. `## Skills`. Pointers only: `exxo-common:claude-design-workflow`, `exxo-common:working-with-figma`, `exxo-common:agent-chrome-screenshots`, `design:design-critique`, `design:accessibility-review`, `design:design-handoff`, `design:ux-copy`, `design:design-system`. Plus stack skills chosen from what the repo uses (read its `package.json` / lockfile), e.g. `mantine-docs` when the repo uses Mantine.

- [ ] **Step 1: Write the failing checks.** Append to `tests/claude-agents-lint.sh` before line 35:

```bash
U="$AGENTS/ux-designer.md"
if [ -f "$U" ]; then
    ufm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$U")"
    utools="$(printf '%s\n' "$ufm" | sed -n 's/^tools: *//p' | tr -d ' ' | tr ',' '\n')"
    [ "$(printf '%s\n' "$ufm" | sed -n 's/^model: *//p')" = opus ] || err "ux-designer: model must be opus"
    for t in Read Grep Glob Bash Write Skill SendMessage ListAgents ToolSearch Artifact ArtifactComments \
             mcp__playwright__browser_navigate mcp__playwright__browser_take_screenshot mcp__claude_ai_Figma__whoami mcp__claude_ai_Figma__use_figma; do
        printf '%s\n' "$utools" | grep -qx "$t" || err "ux-designer: tools lacks $t"
    done
    for t in Edit NotebookEdit Agent mcp__playwright__browser_type mcp__playwright__browser_fill_form mcp__playwright__browser_evaluate mcp__playwright__browser_run_code_unsafe; do
        printf '%s\n' "$utools" | grep -qx "$t" && err "ux-designer: tools must not include $t"
    done
    for s in 'ux-designer ready:' 'exxo-common:claude-design-workflow' 'exxo-common:working-with-figma' \
             'design:design-critique' 'design:accessibility-review' 'design:design-handoff' 'ArtifactComments' \
             'ux-designer-<your name>' '## Handshake' '## Round' '## Wrap-up'; do
        grep -qF -- "$s" "$U" || err "ux-designer: body lacks $s"
    done
    grep -nE '7797|squad/gui|localhost:[0-9]+|[Mm]antine' "$U" | grep -viE 'e\.g\.|example' && err "ux-designer: names a concrete app/stack outside an example"
else
    err "missing agent ux-designer.md"
fi
```

Append to `tests/claude-sync-agents.sh`, inside the `for ctx in exxo exxo-personal` loop after line 59: `check "$ctx: ux-designer not linked (personal-only)" test ! -e "$d/ux-designer.md" -a ! -L "$d/ux-designer.md"`. After line 49 add: `check "personal sees ux-designer" test -e "$FAKE/.claude-personal/agents/ux-designer.md"`.

- [ ] **Step 2: Run to verify it fails**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-agents-lint.sh; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-sync-agents.sh | grep FAIL`
Expected: `FAIL: missing agent ux-designer.md`, and FAIL on `personal sees ux-designer`.

- [ ] **Step 3: Write `files/claude/agents/ux-designer.md`** per the frontmatter and outline above.

- [ ] **Step 4: Run to verify it passes**

Run: `bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-agents-lint.sh; bash /Users/tim/dev/dotfiles-feat-ux-designer-peer/tests/claude-sync-agents.sh | tail -1`
Expected: `ok: 8 agents lint clean`, then `all claude-sync agents tests passed`.

- [ ] **Step 5: Docs.** Add the one sentence to the claude-workstation-setup subagent section. Confirm that `files/claude/CLAUDE.md.shared` is untouched: `git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer diff main -- files/claude/CLAUDE.md.shared` should be empty.

- [ ] **Step 6: Commit**

```bash
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer add files/claude/agents/ux-designer.md tests/claude-agents-lint.sh tests/claude-sync-agents.sh files/claude/skills/claude-workstation-setup/SKILL.md
git -C /Users/tim/dev/dotfiles-feat-ux-designer-peer commit -m "agents: ux-designer peer (experimental, personal-only, opus, tools allowlist)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Fb4jhg5BH2iRtC6sb91kA3"
```

---

### Task 6: Branch gate

- [ ] **Step 1: Run the whole local check once**

Run: `cd /Users/tim/dev/dotfiles-feat-ux-designer-peer && for t in tests/*.sh; do bash "$t" >"$TMPDIR/$(basename "$t").log" 2>&1 || echo "FAIL $t"; done; python3 -m pytest -q tests/ 2>&1 | tail -2; shellcheck scripts/claude-kickoff scripts/ux-designer-peer`
Expected: no `FAIL` lines, pytest all passed, and no shellcheck output. A failing script unrelated to this branch is re-run once on its own; if it then passes, report it as a suspected flake.

- [ ] **Step 2: Check claude-sync against the real contexts (read-only)**

Run: `/Users/tim/dev/dotfiles-feat-ux-designer-peer/scripts/claude-sync --diff 2>&1 | grep -nE 'exxo-skills|exxo-common|ux-designer|settings'`
Expected: personal and reserve show settings drift, adding `exxo-common@exxo-skills` and the `exxo-skills` marketplace. exxo, exxo-personal and exxo-openrouter show no plugin drift. The agents line says `personal-only, not linked: ux-designer` for the curated contexts. Do not apply. claude-sync runs from the primary checkout after merge.

- [ ] **Step 3: Push the branch to draft PR #300** only when the orchestrator says so.

---

### Task 7: Trial launch (operator session, Tim present; not CI)

**Needs Tim present:** it may raise a Figma sign-in, a folder-trust or permission prompt. Say what will appear before each step, and wait (10+ minutes) rather than cancelling.
**Depends on:** Exxo-Labs/skills#79 merged (claude-design-workflow refresh), Exxo-Labs/skills#80 merged with the exxo-common plugin installed or updated from it (until then the Exxo `run-with-secrets` description is broad and collides with the homelab copy), and this branch merged to main on Tim's direction. Personal's `agents/` and `skills/` are whole-dir symlinks into the primary checkout, which stays on main, so the agent and skill are visible only after the merge.

- [ ] **Step 1: Deploy.** Run `~/dev/dotfiles/scripts/claude-sync`. Then, once per context, run `CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude plugin install exxo-common@exxo-skills`, and the same for `.claude-reserve`. If the marketplace is not yet known there, run `claude plugin marketplace add git@github.com:Exxo-Labs/skills.git` first. Check: `claude plugin list` under each dir shows exxo-common enabled. In a fresh personal session, confirm `exxo-common:claude-design-workflow` and `exxo-common:working-with-figma` are listed.
- [ ] **Step 2: Launch.** In a personal-context builder session inside tmux, in a repo with a local dev server running, run `/ux-designer start http://localhost:<port> "<small scope>"`. Record the `@N`.
- [ ] **Step 3: Handshake.** It should arrive as a message. Record which model ran: the handshake `model:` line, cross-checked with `tmux show-options -p -t @N @agent_model` and `/status` in the designer window. Expected: opus (the brief's explicit `model: opus`). Also run once with a brief edited to `model: sonnet`, to confirm that an explicit brief model beats the agent pin.
- [ ] **Step 4: Tool resolution.** In the designer window, ask it to `ToolSearch` and call one harmless operation per allowlisted tool family: `SendMessage` (the handshake itself), `ListAgents`, `Artifact` quickstart `intent: design`, `ArtifactComments` list on the canvas, `mcp__playwright__browser_navigate` + `take_screenshot`, and `mcp__claude_ai_Figma__whoami`. Record resolves / missing / prompted for each. Also check whether `--name` set the name `ListAgents` shows.
- [ ] **Step 5: Adjust.** If a tool did not resolve under its explicit name, try the server-level form (`mcp__claude_ai_Figma`, `mcp__playwright`) in `tools:`. Also check whether `--agent`'s allowlist applied to the main session at all (e.g. `Edit` refused). Put the changes on a new branch from main, with a re-run of `bash tests/claude-agents-lint.sh` and a follow-up PR. Record the findings in the spec's "Settled" section.
- [ ] **Step 6: Close.** `/ux-designer stop`, then confirm that `tmux list-windows` no longer shows `@N` and that the builder's session is intact.
