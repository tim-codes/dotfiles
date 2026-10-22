# Subagent and plugin hygiene: dedicated agents on cheaper models

Status: draft for approval — 2026-10-23
Final home: dotfiles `docs/superpowers/specs/` (this is a dotfiles change,
built in a worktree per the repo rule). Independent of the squad platform.

## 1. Intent

`/usage` attributes 60% of Tim's Claude usage to "general-purpose"
subagents and recommends a cheaper model for them. A transcript scan of
every session since July (1,152 Agent calls, 1.36B subagent tokens by
cost proxy) says precisely where that goes and makes a better fix
possible: split the general-purpose population into purpose-dedicated
agents that carry their own procedure, run those on cheaper models
because they need less judgment, and shrink general-purpose over
iterations. This document is the first round; the scanner it was
measured with becomes a repo script so the next rounds are measured the
same way.

## 2. Evidence (scan of 2026-07-07 → 2026-10-23)

- 85% of Agent calls are general-purpose/default. general-purpose with
  `model: opus` alone is **51% of all tokens** (447 calls). Sonnet
  general-purpose ran 398 calls for a fifth of the cost.
- By theme, share of general-purpose spend: implement (plan lane/task)
  31%, git/PR ops 11%, review 10% (207 calls, the most frequent),
  investigate/debug + CI forensics 13%, Sanity/CMS 7%, ad-hoc implement
  6%; Linear/Notion/Slack/M365 together ~4% and already on sonnet.
- Notion MCP: 645 calls in 24 of 69 exxo sessions, 82% from subagents;
  Vercel MCP: 103 calls in 14 exxo sessions. Personal: zero of either.
  The Notion/Vercel **plugin skills** were invoked 0 and 1 times
  respectively — they are the ~525 tok/turn in the footprint, the MCP
  servers are not.
- Notion runs as three servers in exxo (`plugin_Notion_notion` from the
  plugin, `claude_ai_Notion` from the account connector, legacy
  hand-added `notion`); Linear as two (`plugin_linear_linear`,
  `claude_ai_Linear`). Figma: 333 calls confined to 3 sessions.
- Sessions: 28 over 8h, 19 over 24h.

## 3. Goals, non-goals

**Goals**
1. General-purpose share of subagent tokens below 25% within 30 days,
   measured by the same scanner.
2. Every dedicated agent has a model pinned in its definition and a
   procedure good enough that a weaker model succeeds.
3. The plugin skill-listing footprint drops by the Notion and Vercel
   share (~525 tok/turn) in every context.
4. One Notion server and one Linear server per context, not three/two.

**Non-goals**
- Removing Notion/Vercel capability from exxo — the scan shows real use.
- Touching the claude.ai account connectors (`claude_ai_*`): those are
  managed on claude.ai, not here.
- Per-agent cost accounting in the harness.

## 4. Decisions

### 4.1 Dedicated agents, round one

Definitions live in dotfiles `files/claude/agents/<name>.md` (frontmatter
`name`, `description`, `model`, `tools`; body = procedure). Spend is 92%
exxo, so they must reach the exxo context: **claude-sync grows an
`agents/` delivery path mirroring skills** — personal gets a
whole-directory symlink, exxo gets a curated dir from a `shared_agents()`
allow list — and all six below are shared. (My call; the alternative is
the exxo-skills plugin, which would make them org property and lag behind
main.)

| agent | model | covers | notes |
|---|---|---|---|
| `implementer` | sonnet | plan-lane and ad-hoc implementation | caller passes `model: opus` explicitly for design-sensitive lanes; procedure: read the plan/task, TDD per repo conventions, commit, report diff summary |
| `reviewer` | sonnet | code/spec review, re-review waves | confidence-filtered findings only; no fixes unless asked |
| `git-pr-ops` | sonnet (haiku allowed) | branch surveys, PR create/update, worktree closedown, merge-state checks | mechanical; restates SSH-remote and worktree rules; uses `worktree-closedown` |
| `investigator` | sonnet | debugging, CI/build log forensics, prod smoke follow-ups | scrollback stays with the agent; returns cause + evidence |
| `sanity-cms` | sonnet | Sanity schema/content/Studio work | loads `mantine-docs`/Sanity rules as its procedure says |
| `notion-ops` | sonnet | all Notion reads/writes | the one place Notion tooling is loaded in a session; Notion MCP calls from other agents become a `notion-ops` delegation |

Each body must restate the environment mechanics subagents don't inherit
(secret cache via `run-with-secrets`, command runners, explicit targets),
per the global delegation rule.

### 4.2 Delegation policy text

`files/claude/CLAUDE.md.shared` orchestrator/subagent section gains:
route to a dedicated agent first; `general-purpose` is the fallback and
the roster line must say why; `model` defaults come from the agent
definition — pass `opus` only with a one-line reason. The self-audit
clause is extended: a general-purpose launch for an implement/review/
git/investigate/Sanity/Notion-shaped task is a miss to correct next turn.

### 4.3 Plugins and MCP servers

- Remove the `Notion` and `vercel` plugins from `enabledPlugins` in
  `settings.shared.json`/`settings.exxo.json` (their skills are unused;
  removing the Notion plugin also removes the `plugin_Notion_notion`
  server). Vercel's skills/agents are reachable again by re-enabling the
  plugin for a session that needs them — that is the "lazy load".
- exxo keeps the `claude_ai_Notion` and `claude_ai_Linear` account
  connectors; the legacy hand-added `notion` server is retired per context
  with `claude mcp remove -s user notion`; the `linear` plugin is removed
  for the same duplication reason **after** confirming nothing depends on
  its `linear-tpe` agent (1% of usage) — builder verifies, keeps the
  plugin if it does.
- Personal: ensure no Notion/Vercel server or plugin is present.
- Figma: leave the plugin disabled by default in the fragments and
  document "enable for the session" in the skill; same lazy-load pattern.

### 4.4 Measurement

Promote the scanner to `scripts/claude-usage-scan` (stdlib Python,
`python3 -I`); add a `--compare <json>` to diff two runs. Record the
baseline JSON from today under `docs/superpowers/specs/` next to this
file. The 30-day re-run is a backlog item with a date.

## 5. Backlog (later rounds)

- **2026-11-22: 30-day re-measure.** `scripts/claude-usage-scan
  --aggregate-only --compare docs/superpowers/specs/2026-10-23-usage-baseline.json`;
  goal 1 is `gp_token_share_pct` < 25 in the window period (baseline:
  92.1% window, 91.9% all-time by the scanner's cost proxy). The baseline
  is recorded `--aggregate-only` — no task descriptions, project names or
  UUID server names — because this repo is public.
Further splits by evidence: `m365-ops`, `browser-tester`, `infra-pulumi`,
`docs-research`, `linear-ops`. Figma plugin lazy-load helper. A
`session-janitor` note in the squad orchestrator design covers the
>8h-session recommendation.

## 6. Left to the builder

Agent body wording; the claude-sync `agents/` implementation details
(mirror `shared_skills()` exactly); whether `tools` restrictions per agent
are worth it in round one; the `--compare` output format.

## 7. Calls I made

- Agents delivered via claude-sync `agents/` path, shared to exxo.
- Implementer on sonnet by default (Tim's choice); git-pr-ops sonnet with
  haiku permitted.
- Remove Notion/Vercel plugins everywhere; keep exxo connectors; retire
  the legacy `notion` server.
- Target: general-purpose < 25% of subagent tokens in 30 days.
