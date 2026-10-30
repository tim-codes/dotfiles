---
name: squad-planner
description: Plan one squad task into a TaskPlan and submit it to the squad orchestrator with submit_task — headless over a task file when the broker launches a planner, or interactively with Tim. Reads the squad context brief for the repo, drives brainstorming and plan-writing, composes the task markdown with its plan frontmatter, and handles validation problems, resubmission and scope changes. Use for "/squad-planner", "plan this for the squad", or a headless launch carrying --headless --task-id.
argument-hint: "[--headless --task-id N --repo owner/name --task-file PATH] | [--draft] [task file or description]"
---

# Squad planner

One skill, two callers, one artifact. The broker runs it headless over a task
file; Tim runs it in his own session. Either way the result is the same task
markdown and the same `TaskPlan`, passed to `mcp__squad__submit_task`, so the
orchestrator never needs to know which way a plan was made.

## Invocation

| Form | Session | Arguments |
|---|---|---|
| Headless | `planner` kind, launched by the broker, nobody watching | `/squad-planner --headless --task-id <int> --repo <owner/name> --task-file <abs path>` |
| Interactive | Tim's own session (`operator` kind) | `/squad-planner [--draft] [<task file path> \| <description>]` |

- `--headless` selects the headless form; all three of its other arguments
  are required. A headless session **never asks anyone anything**: no
  `AskUserQuestion`, and no turn ends with a question. Every assumption and
  every unresolved question goes under `## Open questions` in the content.
- Interactive disambiguation: drop a leading `--draft`. If what remains names
  an existing readable file (after `~` expansion), it is the task file;
  otherwise the whole remaining text is a description of the work. Nothing
  left: ask Tim what to plan. The interactive form may ask Tim questions, one
  at a time.
- `--draft` is the opt-out from approval. Without it, an interactive
  submission counts as Tim's design approval (spec §6.2) and the task enters
  preflight.

## What a planner does

- It plans only: no worktrees of its own, no launches, no messages to
  members, no commits, no file writes. The task markdown is composed in
  context and passed as `content`: compose, do not save. The only exception
  is the interim file drop in step 5 when no orchestrator is reachable.
- It never calls `ExitPlanMode`: the plan goes to `submit_task`, not to a
  mode switch. The broker launches planners in plan mode (contracts README
  rule 7), but the skill relies on no permission mode and works read-only in
  all of them.
- Of the squad's tools it uses `mcp__squad__submit_task` and the resources
  only (`squad://context-brief/...`, `squad://me`).
- Its own delegation: dedicated agents first (`Explore` for read-only
  sweeps of the repo, `notion-ops` for every Notion read or write,
  `implementer` for an interactive draft PR); `general-purpose` only with an
  explicit `model` (a PreToolUse guard rejects it otherwise); no forks. A
  subagent brief restates what it needs, since skills do not travel.

## 1. Repo and context brief

- Repo: headless takes `--repo`. Interactive reads `git remote get-url origin`
  and converts it to `owner/name` (`git@github.com:o/n.git` and
  `https://github.com/o/n` both give `o/n`); if the task file or Tim names
  another repo, that one; if there is no remote, ask Tim.
- First check whether the squad is reachable: `mcp__squad__submit_task` is
  among this session's tools, counting deferred tools (search for it with
  ToolSearch before concluding it is absent).
- Read `squad://context-brief/<owner>%2F<name>` (the repo URL-encoded, so `/`
  is `%2F`) with ReadMcpResourceTool, server `squad`. It returns the repo's
  `tasks`, `members` with their branches or trunks, `pending_items`, `quota`
  headroom per account, `recent_decisions` and the current `batch`. Say in
  three to five lines what the squad is doing in that repo; this becomes the
  `## Context` of the content.
- If the read fails (orchestrator down): headless hands back `failed` with
  code `no_submission` (step 8); interactive tells Tim and stops.
- Headless, any failure before a submission (a missing argument, an
  unreadable `--task-file`, `mcp__squad__submit_task` absent, the brief
  unreadable) ends the turn with the `failed` hand-back, code
  `no_submission`, never with prose alone.
- No orchestrator yet (interactive only): if `mcp__squad__submit_task` is
  absent, the squad is not reachable from here at all; skip the read.
  Tell Tim, write "context brief unavailable" under `## Context`, and carry on;
  step 5 then uses the interim file drop.

## 2. Shape the work

**Interactive.** Follow `superpowers:brainstorming` for the conversation (one
question at a time, two or three approaches with a recommendation) and
`superpowers:writing-plans` for decomposition (deliverables sized so each has
its own check). Skip both skills' "write a doc under docs/ and commit" and
"execution handoff" steps: the task markdown is the artifact and
`submit_task` is the hand-off. If the argument was a file, `Read` it first and
plan from it. Then apply Tim's planning guidance:

- **Linear, without sprawl.** Look for an existing ticket first. Prefer one
  ticket with sub-issues (one per deliverable only where that helps); a
  Linear project only for very large works. Propose the shape to Tim, create
  or update the tickets once he agrees, and list their ids and URLs under
  `## Tickets`.
- **OpenSpec draft PR (optional).** When the work is spec-shaped, or the repo
  already uses `openspec/`, offer a draft PR carrying the OpenSpec change,
  written to `exxo-common:openspec-changes` conventions and tied to the
  tickets. On Tim's yes, an `implementer` subagent produces it in its own
  worktree (the brief restates the worktree rule and that the PR stays a
  draft); the planner itself still writes nothing. Reference it under
  `## Decisions`.
- **ADR.** When the plan makes an architectural choice, propose a repo ADR
  following that repo's ADR conventions (its `docs/adr/` or equivalent),
  produced the same way, ideally in the same draft PR. Reference it under
  `## Decisions`.
- **Notion docs estate.** Have `notion-ops` find the Notion pages the work
  touches and report what they say. Where the plan diverges from them or
  leaves them stale, propose the amendment or addition to Tim in the session;
  apply it through `notion-ops` only on his say-so. Record proposed and
  applied amendments under `## Docs amendments`. Never diverge silently.
- **Model and effort.** Recommend the model and effort the squad should pick
  the work up with, with one line of why, under
  `## Recommended model and effort`.

**Headless.** `Read` the task file and explore the repo read-only. Ask no
one. Create no tickets, PRs, ADRs or Notion edits: under `## Tickets` and
`## Decisions` carry over the references the task file already has; under
`## Docs amendments` note documentation you saw that the work will make
stale; under `## Recommended model and effort` give your recommendation.
Record each assumption and each unresolved question under
`## Open questions`.

## 3. Fill the TaskPlan

The plan is strict: no fields beyond these, and an absent optional field is
omitted, never `null`.

- `title`: 1–200 characters, what the task delivers.
- `deliverables`: 1–50 entries `{name, check}`; `name` 1–200 characters,
  `check` 1–2000 characters, something a reviewer can run or observe.
- `depends_on` (optional): up to 50 task ids, only ids present in the
  brief's `tasks`, never the task's own id.
- `resources`: `repo` (`owner/name`); `base` (a branch or a `trunk/...` named
  in the brief, else the default branch); `capabilities` (up to 16 tags of
  `[a-z0-9-]`, may be empty); `heavy_jobs` (up to 20 `{command,
  est_minutes}` with `est_minutes` 1–240, may be empty); `account` (optional,
  a name from the squad config's `[[accounts]]`, only when the work is bound
  to one); `model` (optional, only when a model is a hard requirement; a
  preference goes under `## Recommended model and effort`).
- `operator_steps`: up to 50 (may be empty), each `{title, class}` plus
  `instructions`, `commands` and `est_minutes` where known. `class` is
  `blocks_launch` when it must be done before the member starts (credentials,
  accounts, access) or `blocks_step` when it is needed at a named point
  mid-work.
- `infra` (optional): up to 10 `{stacks, summary}` (1–20 stacks, summary
  1–2000 characters) whenever supporting infra is needed, so the orchestrator
  creates the exxo-infra dependency task that lands first (spec §8).
- `kickoff_brief`: 1–50000 characters, `kickoff-template.md` in this
  directory filled in: replace every `<…>`; keep the merge-authority line
  that applies, remove its brackets and delete the other. A new task with no
  id yet (an interactive submission without `task_id`) writes the task line
  as `Task: <title>`; headless and revisions write `Task <id>: <title>`. When
  `resources.heavy_jobs` is not empty, list its commands under
  `## Test policy`, so the member asks for a slot before running them. Its
  first two lines stay exactly as the template has them.
- `merge_authority`: `trunk_service`, unless Tim says he merges this one
  himself, then `operator`.
- `test_policy`: one line, 1–2000 characters; default
  `squad-member, Testing and trunks`, or the exception (e.g. a browser smoke
  needing a heavy slot).
- `priority_suggestion`: 1 (highest) to 5.

## 4. Compose the task markdown

Compose, do not save. `content` is:

```text
---
<the TaskPlan as JSON, 2-space indent>
---

<body>
```

ending with a newline. The frontmatter JSON is the `plan` argument exactly
(JSON is valid YAML, and the orchestrator refuses a mismatch with
`frontmatter_mismatch`). When a task file was given, `content` is that file's
text with this frontmatter added at the top (or replacing the frontmatter it
already has), its body kept and extended with the headings below where they
are missing. Otherwise it is new text. Body headings, in this order:

- `# <title>`
- `## Context`: what the squad is doing in the repo, from the brief.
- `## Approach`
- `## Deliverables`: each with its check.
- `## Tickets`: Linear ids and URLs (see step 2).
- `## Decisions`: ADR and OpenSpec references.
- `## Docs amendments`: Notion amendments proposed or applied.
- `## Recommended model and effort`
- `## Open questions`: headless only; may be empty.
- `## Scope change`: only for a resubmission to a running task (step 7).

## 5. Submit

Call `mcp__squad__submit_task` with `content`, `plan`, and:

- `task_id`: headless, always the `--task-id`; interactive, only when
  revising an existing task.
- `draft`: headless (a `planner` session), always `true`. Interactive (an
  `operator` session): omit it, because the submission is Tim's design
  approval (spec §6.2); `true` only when he invoked `/squad-planner --draft`
  or asks in the session for GUI approval instead.
- No hash field: the orchestrator computes the content hash itself.

Before an interactive submission without `--draft`, show Tim the composed
markdown and tell him that submitting approves it; submit on his go-ahead.

The answer is `{task_id, state}` (plus the orchestrator's hash of the
content, which needs no action).

**Interim, no orchestrator (interactive only).** When
`mcp__squad__submit_task` is absent (step 1's check), never drop the
plan. Write the composed `content` (frontmatter and body, exactly what would
have been passed to `submit_task`) to `<kickoff dir>/<task-slug>.md`, where
`<task-slug>` is the title in lower-case kebab case (at most 60 characters;
add `-2`, `-3` … rather than overwrite an existing file). The kickoff dir is
`kickoff_dir` under `[orchestrator]` in `~/.config/squad/config.toml` when
set, else `~/squad/kickoff` (the config schema's default); create it if
missing. Tell Tim the path, and that the orchestrator picks the file up from
the kickoff directory at the cut-over, where it goes through intake and
approval like any dropped file (so this is not an approval, whatever
`--draft` said). With the tool present, the MCP path is authoritative and
nothing is written to disk.

## 6. Problems

A refused call returns a `ToolError` `{code, message, problems?}`.

| Code | Headless | Interactive |
|---|---|---|
| `invalid_plan` | Fix every `problems[].path`, resubmit. | Same; tell Tim what changed. |
| `frontmatter_mismatch` | Regenerate the frontmatter from `plan`, resubmit. | Same. |
| `unknown_task` | Hand back `failed`. | Resubmit without `task_id` only if Tim agrees. |
| `task_running` | Never retry from a planner session; hand back `failed`. | Not raised for an operator session (step 7). |
| `not_allowed_for_kind` | Hand back `failed`. | Tell Tim this session cannot submit; offer the interim file drop. |
| `invalid_input` | Hand back `failed`. | Show Tim the message. |

A schema rejection (the MCP SDK's validation text, not a `ToolError`) is
treated like `invalid_plan`: fix the named fields and resubmit, reporting it
as `invalid_input` if it ends in failure. At most three submissions per turn;
after the third refusal headless hands back `failed` with the last code, and
interactive shows Tim the problems and asks how to proceed.

## 7. Resubmission and scope change

- An amendment (a `plan_amended` turn, or any later turn in the same session
  asking for changes) is applied and resubmitted with the same `task_id`,
  replacing the pending plan. A headless turn ends with a fresh hand-back
  line under the rule in step 8.
- From Tim's interactive session, a resubmission for a `running` task becomes
  a scope-change directive to the member (spec §6.2–§6.3). Do it only when
  Tim asks for it, and quote his words verbatim, with the date, under
  `## Scope change`; never paraphrase them.
- `squad://me` lists the tasks this session submitted with their state and
  revision, to see whether a plan was approved, amended or rejected.

## 8. Hand back

**Headless.** The last non-empty line of the session's final message is one
whole-line JSON object, on its own line, never inside a code fence, with
nothing after it:

- `{"squad_planner":"submitted","task_id":<int>,"state":"<task_state>"}`
- `{"squad_planner":"failed","task_id":<int>,"code":"<ToolError code or no_submission>","message":"<one line>"}`

The orchestrator reads the tail of the final message, drops trailing blank
lines and parses the last line as JSON with a `squad_planner` key; anything
else counts as no hand-back. Summary prose may come before it. Then end the
turn. The `submit_task` call itself is the authoritative record of the plan.

**Interactive.** Tell Tim the task id and state: a `--draft` plan waits on
the GUI's task screen, an approved one goes to preflight. For an interim file
drop, the path instead.
