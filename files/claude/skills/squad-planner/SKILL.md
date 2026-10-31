---
name: squad-planner
description: Plan one squad task into a TaskPlan and submit it to the squad orchestrator with submit_task — headless over a task file when the broker launches a planner, or interactively with Tim, resuming a local draft when given one. Reads the squad context brief for the repo, drives brainstorming and plan-writing, composes the task markdown with its plan frontmatter, and handles validation problems, resubmission and scope changes. Use for "/squad-planner", "plan this for the squad", or a headless launch carrying --headless --task-id.
argument-hint: "[--headless --task-id N --repo owner/name --task-file PATH] | [draft, task file or description]"
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
| Interactive | Tim's own session (`operator` kind) | `/squad-planner [<draft path> \| <task file path> \| <description>]` |

- `--headless` selects the headless form; all three of its other arguments
  are required. A headless session **never asks anyone anything**: no
  `AskUserQuestion`, and no turn ends with a question. Every assumption and
  every unresolved question goes under `## Open questions` in the content.
- Interactive disambiguation: if the argument names an
  existing readable file (after `~` expansion) under
  `~/.local/state/squad/plans/`, it is a draft to resume (`## Drafts`); any
  other existing readable file is the task file;
  otherwise the whole argument is a description of the work. Nothing given: ask Tim what to
  plan. The interactive form may ask Tim questions, one at a time.
- Interactive posture is drafting, with no flag. The planner iterates the
  plan with Tim in the session and keeps its artefacts (plan documents, a
  draft PR, Linear tickets) in the open as it goes, but submits nothing to
  the squad until Tim says in his own words that the plan is accepted or
  finalised (step 5). The submission is then his design approval (spec
  §6.2) and the task enters preflight.

## What a planner does

- The headless planner plans only: no worktrees, no PRs, no launches, no
  messages to members, no commits, no file writes. Its task markdown is
  composed in context and passed as `content`: compose, do not save.
  The interactive planner instead keeps the task markdown in a local draft
  file (`## Drafts`), and also keeps the plan documents, draft
  PR and Linear tickets of step 2 and its planning claim in the
  orchestrator (`## Sibling planners`); it still makes no launches and sends
  no messages to members.
- It never calls `ExitPlanMode`: the plan goes to `submit_task`, not to a
  mode switch. The broker launches headless planners in `auto` permission
  mode, not plan mode (plan mode ignores allow rules for non-read-only tools,
  which made every planner raise a permission item for `submit_task`). Auto
  mode is not a licence to edit: the planner still does no repo edits and
  only reads. `mcp__squad__submit_task` needs no operator prompt, because the
  broker answers the squad's own tools itself; if a permission prompt for it
  ever appears, do not work around it, hand back `failed` with code
  `no_submission`. The skill relies on no permission mode: headless works
  read-only in all of them.
- Of the squad's tools it uses `mcp__squad__submit_task`,
  `mcp__squad__heavy_slot` (below) and, interactive
  only, `mcp__squad__claim` (`## Sibling planners`), plus the resources
  (`squad://context-brief/...`, `squad://me`). Plans reach the squad only
  through `submit_task`; nothing is written to a directory the orchestrator
  watches, and no file records what a planner holds (a draft is personal
  scratch, never a claim).
- **Heavy slots.** The heavy gate applies to headless planners too. Before
  `just check`, `cargo test` or any other command matching the heavy patterns
  that plan validation needs, call `mcp__squad__heavy_slot` with
  `{action: "request", est_minutes: <1-240>, reason: "<one line>"}`; a
  `queued` answer means end the turn's work on that step and wait for the
  grant turn, and the gate denies the command without one, so do not try
  first. Release with `{action: "release"}` as soon as the command ends or
  fails. If the slot is denied (or would not arrive in reasonable time), skip
  that heavy step, plan without it, and say so in the plan hand-back: name the
  skipped command under `## Open questions` and in the summary prose before
  the hand-back line. Prefer focused read-only checks, and take no slot for
  them.
- Its own delegation: dedicated agents first (`Explore` for read-only
  sweeps of the repo, `notion-ops` for every Notion read or write,
  `implementer` for the interactive plan documents); `general-purpose` only with an
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
  headroom per account, `recent_decisions`, the current `batch` and the
  `planning_claims` that sibling planners hold (`## Sibling planners`). Say in
  three to five lines what the squad is doing in that repo; this becomes the
  `## Context` of the content.
- If the read fails (orchestrator down): headless hands back `failed` with
  code `no_submission` (step 8); interactive carries on as below, with no
  orchestrator.
- Headless, any failure before a submission (a missing argument, an
  unreadable `--task-file`, `mcp__squad__submit_task` absent, the brief
  unreadable) ends the turn with the `failed` hand-back, code
  `no_submission`, never with prose alone.
- Interactive: tell Tim what the brief's `planning_claims` show siblings
  holding (`## Sibling planners`) before step 2, and keep clear of it.
- No orchestrator reachable (interactive only): if `mcp__squad__submit_task`
  is absent, or the brief cannot be read, the squad is not reachable from
  here; skip the read and the claim. Tell Tim, write "context brief
  unavailable" under `## Context`, do the sibling check on the Linear labels
  alone, and plan to the end anyway: plan documents, draft PR, Linear ticket
  and the draft file, which on acceptance is left ready to submit (step 5,
  "Squad unreachable").

## 2. Shape the work

**Interactive.** Follow `superpowers:brainstorming` for the conversation (one
question at a time, two or three approaches with a recommendation) and
`superpowers:writing-plans` for decomposition (deliverables sized so each has
its own check). Skip both skills' "write a doc under docs/ and commit" and
"execution handoff" steps: the plan documents below and the task markdown are
the artefacts, and `submit_task` is the hand-off. If the argument was a file,
`Read` it first and plan from it.

From the settled point, the planner keeps the following current. The settled
point is when the brief is clear enough: the repo, the scope and an outline of
the deliverables agreed with Tim, after the sibling check. At that point the
planner also claims its scope with the orchestrator and labels its tickets
(`## Sibling planners`) and writes the draft file (`## Drafts`). Each time the
plan changes materially, it updates the draft file, the plan documents, the
draft PR and Linear in the same step.

- **Plan documents and draft PR.** In the target repo's worktree, which the
  planner creates with `wt -C <repo> switch --create plan/<slug> --base
  <base> --no-cd -y` (`<base>` is the brief's base or the repo's default
  branch), write the plan documents: an OpenSpec change written to
  `exxo-common:openspec-changes` conventions where the repo uses
  `openspec/`, otherwise the repo's own plan convention (its CLAUDE.md or
  docs say where; ask Tim if there is none); and an ADR following the repo's
  ADR conventions whenever the plan makes an architectural choice. Open a
  DRAFT PR carrying them against the base and keep updating it as the plan
  iterates, pushing at checkpoints rather than on every edit. An
  `implementer` subagent does the writing in that worktree; the planner
  writes inline instead when the plan documents are one short file, such as
  a single ADR. The subagent brief restates, since skills do not travel:
  the absolute worktree path (the `wt ... --no-cd` output) and that it works
  only there; `exxo-common:openspec-changes`, and that `openspec validate
  <id> --strict` passes before it hands back; the base as `origin/<base>`
  after a fetch; the exact commit trailer lines and PR body footer, passed
  verbatim from this session's attribution instructions; and that it opens
  the PR, as a DRAFT, with `-R <owner/name>` over the SSH remote, and never
  merges it. Reference the PR and documents under `## Decisions`.
- **Linear, mirrored.** Look for an existing ticket first, excluding
  siblings' (`## Sibling planners`). Keep to one parent ticket with
  sub-issues; a Linear project only for very large works. At the settled
  point create or take the parent ticket and label it `squad:planning`. From
  then on the parent's description mirrors the current plan summary (goal,
  approach, a link to the draft PR) and the sub-issues mirror the
  deliverables, one each, each labelled `squad:planning` when created. When the
  plan changes materially, update the parent and add, retitle or close
  sub-issues in the same step as the draft PR. While
  drafting, the parent sits in the team's planning or backlog state; on
  acceptance it moves to the team's ready or todo state (step 5). List ids
  and URLs under `## Tickets`. If the session has no Linear tools, tell Tim
  which tickets and updates the planner would make, and carry on.
- **Notion docs estate.** Have `notion-ops` find the Notion pages the work
  touches and report what they say. Where the plan diverges from them or
  leaves them stale, propose the amendment or addition to Tim in the session;
  apply it through `notion-ops` only on his say-so. Record proposed and
  applied amendments under `## Docs amendments`. Never diverge silently.
- **Model and effort.** Recommend the model and effort the squad should pick
  the work up with, with one line of why, under
  `## Recommended model and effort`.

**Headless.** `Read` the task file and explore the repo read-only. Ask no
one. Read the task file's frontmatter first: if it already carries a
complete, valid TaskPlan, step 4's as-is rule applies and this step shrinks to
checking it. Otherwise its `resources` (step 3) are the intake's and travel
into the plan. Hold no planning claim (the task already exists). Create no tickets, PRs, ADRs or Notion edits: under `## Tickets` and
`## Decisions` carry over the references the task file already has; under
`## Docs amendments` note documentation you saw that the work will make
stale; under `## Recommended model and effort` give your recommendation (Sonnet unless the work needs more).
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
  in the brief, else the default branch); `capabilities` (up to 16 tags,
  each matching `^[a-z0-9][a-z0-9-]{0,31}$`, may be empty); `heavy_jobs` (up to 20 `{command,
  est_minutes}` with `est_minutes` 1–240, may be empty); `account` (optional,
  a name from the squad config's `[[accounts]]`, only when the work is bound
  to one); `model` (optional, only when a model is a hard requirement; a
  preference goes under `## Recommended model and effort`). Never invent a
  model: the default guidance is Sonnet, which the orchestrator applies when
  the plan names none.
  **Intake resources are carried unchanged.** When the plan is made from a
  task file (headless with `--task-id`, or an uploaded intake), the submitted
  `resources` carry the intake's `model`, `account`, `capabilities`,
  `heavy_jobs` and `base` exactly as the intake has them, adding nothing the
  intake lacks except fields it left out. Change one only for a stated reason,
  written in the plan's notes (`## Approach`, or `## Scope change` on a
  resubmission). The orchestrator refuses a plan that drops an intake field
  with `invalid_plan` and a `resources.<field>` problem path (for example
  `resources.model`); a dropped `model` once sent a task to the context
  default, Opus, at several times the cost.
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
  first two lines stay exactly as the template has them. Where a plan PR or an
  OpenSpec change exists (an interactive plan always has the PR; a headless
  one only if the task file names it), `## Notes` names the plan PR URL and
  the OpenSpec change id and says to run the staleness pass first, rebasing
  onto the kickoff's base (main or the active trunk), so the member cannot
  miss it.
- `merge_authority`: `trunk_service`, unless Tim says he merges this one
  himself, then `operator`.
- `test_policy`: one line, 1–2000 characters; default
  `squad-member, Testing and trunks`, or the exception (e.g. a browser smoke
  needing a heavy slot).
- `priority_suggestion`: 1 (highest) to 5.

## 4. Compose the task markdown

Headless: compose, do not save. Interactive: the composed text is the draft
file (`## Drafts`), written at the settled point and rewritten on every
revision. `content` is:

```text
---
<the TaskPlan as JSON, 2-space indent>
---

<body>
```

ending with a newline. **As-is rule.** When the intake already carries a
complete, valid plan frontmatter (it parses as a TaskPlan and every `depends_on`
id is in the brief's `tasks`), submit the task file's `content` byte-identical,
with the frontmatter parsed into `plan` and nothing re-serialised or
reformatted: the orchestrator's fast path then approves it without a review
run. Anything added or rewritten defeats that, so touch the file only to fix a
problem the validation names. The frontmatter JSON is the `plan` argument exactly
(JSON is valid YAML, and the orchestrator refuses a mismatch with
`frontmatter_mismatch`). When a task file was given without a complete, valid plan frontmatter, `content` is that file's
text with this frontmatter added at the top (or replacing the frontmatter it
already has), its body kept and extended with the headings below where they
are missing. Otherwise it is new text. Body headings, in this order:

- `# <title>`
- `## Context`: what the squad is doing in the repo, from the brief.
- `## Approach`
- `## Deliverables`: each with its check.
- `## Tickets`: Linear ids and URLs (see step 2).
- `## Decisions`: ADR and OpenSpec references, and the plan PR.
- `## Docs amendments`: Notion amendments proposed or applied.
- `## Recommended model and effort`
- `## Approval`: interactive only; Tim's words accepting the plan, quoted
  verbatim, with the date (step 5).
- `## Open questions`: headless only; may be empty.
- `## Scope change`: only for a resubmission to a running task (step 7).

## 5. Submit

Call `mcp__squad__submit_task` with `content`, `plan`, and:

- Interactive, `content` is the draft file's content, read back from the file
  just before the call, and `plan` is its frontmatter parsed; never a version
  held only in context.

- `task_id`: headless, always the `--task-id`; interactive, only when
  revising an existing task.
- `draft`: headless (a `planner` session), always `true`. Interactive (an
  `operator` session): never send it, because the submission is Tim's design
  approval (spec §6.2).
- No hash field: the orchestrator computes the content hash itself.

The answer is `{task_id, state}` (plus the orchestrator's hash of the
content, which needs no action).

**Interactive: the acceptance gate.** Until Tim says in his own words that the
plan is accepted or finalised, the planner does not call `submit_task`.
Agreement to a step ("yes, create the tickets") is
not acceptance of the plan; when unsure, ask whether he accepts it. Show him
the draft file's path and its current content before asking. When he
accepts, in this order:

1. Quote his words verbatim, with the date, under `## Approval` in the draft
   file, then submit. If the call is refused, fix the draft per step 6 and
   resubmit; if the squad turns out to be unreachable, go to "Squad
   unreachable" below. Nothing after this step happens until a submission has
   succeeded.
2. Mark the plan PR ready with `gh pr ready <n> -R <owner/name>`. Never
   merge it.
3. Move the parent ticket to the team's ready or todo state and replace
   `squad:planning` with `squad:planned` on the parent and every sub-issue.
4. Release the planning claim (`## Sibling planners`).

If Tim ends the session without accepting, nothing is submitted, and the
planner says so. The draft PR and the `squad:planning` labels stay for him to
resume or clean up, and the planner tells him which they are; it releases its
planning claim.

**Squad unreachable (interactive only).** When `mcp__squad__submit_task` is
absent (step 1's check) or the call fails without one of step 6's codes (a
transport or connection error, the tool gone, the session's token refused),
the planner submits nothing and does not retry in a loop. It still runs the
acceptance gate: on Tim's acceptance it quotes his words under `## Approval`
in the draft, validates the draft locally (`## Drafts`), marks nothing ready,
moves no ticket, releases any planning claim it holds if `mcp__squad__claim`
still answers (otherwise the orchestrator ages it out), and ends by giving Tim
the draft path and the two ways to submit it later (`## Drafts`).

## 6. Problems

A refused call returns a `ToolError` `{code, message, problems?}`.

| Code | Headless | Interactive |
|---|---|---|
| `invalid_plan` | Fix every `problems[].path`, resubmit. | Same; tell Tim what changed. |
| `frontmatter_mismatch` | Regenerate the frontmatter from `plan`, resubmit. | Same. |
| `unknown_task` | Hand back `failed`. | Resubmit without `task_id` only if Tim agrees. |
| `task_running` | Never retry from a planner session; hand back `failed`. | Not raised for an operator session (step 7). |
| `not_allowed_for_kind` | Hand back `failed`. | Tell Tim this session cannot submit and stop. |
| `invalid_input` | Hand back `failed`. | Show Tim the message. |
| none (unreachable) | Hand back `failed` with `no_submission`. | Keep the draft; step 5, "Squad unreachable". |

A schema rejection (the MCP SDK's validation text, not a `ToolError`) is
treated like `invalid_plan`: fix the named fields and resubmit, reporting it
as `invalid_input` if it ends in failure. At most three submissions per turn;
after the third refusal headless hands back `failed` with the last code, and
interactive shows Tim the problems and asks how to proceed.

## 7. Resubmission and scope change

- An amendment (a `plan_amended` turn, or any later turn in the same session
  asking for changes) is applied and resubmitted with the same `task_id`,
  replacing the pending plan. Interactive, an amendment after acceptance
  first reverts the plan to drafting: `## Approval` removed from the draft
  file, `gh pr ready --undo <n> -R <owner/name>`, the labels back to `squad:planning` on every ticket, the
  parent back in the planning state, and the planning claim taken again. Then it
  updates the plan documents, the PR and the tickets, and resubmits when Tim
  says it is accepted again (his new words, quoted under `## Approval`),
  when the acceptance steps of step 5 run again. A headless turn ends with
  a fresh hand-back line under the rule in step 8.
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

**Interactive.** Tell Tim the task id and state (an approved plan goes to
preflight), that the plan PR is ready, which tickets are `squad:planned`, and
the draft path. If the squad was unreachable, say that nothing was submitted,
what stands (draft file, plan documents, draft PR, ticket) and how to submit
the draft later (`## Drafts`). If he ended
without accepting, say what stays (step 5).

## Drafts

Interactive form only; the headless planner keeps no draft. The draft is the
source of truth for the task markdown: written to a file as the plan takes
shape, kept current on every revision, and the text `submit_task` sends.

- **Where.** `~/.local/state/squad/plans/<owner>-<name>/<yyyy-mm-dd>-<task-slug>.md`,
  the repo's `owner/name` with `/` as `-`, the date the draft was started and a
  short slug of the title. Create the directories with `mkdir -p` and
  `chmod 700` them. It is outside every repo, so it never enters a git
  history, survives the session, and lists per repo with `ls`. It is personal
  scratch: no other session reads it, it records no claim, and it is never
  copied into a directory the orchestrator watches.
- **Shape.** Exactly step 4's task markdown: the TaskPlan as JSON frontmatter
  and the body, the same file `submit_task` and a GUI batch upload accept.
  Until the plan is complete, fill the frontmatter with what is settled and
  keep the gaps visible in the body; it must be a complete TaskPlan before
  acceptance.
- **Validate locally** before asking for acceptance, and again on every
  submission from it: the frontmatter parses (`jq` over the text between the
  `---` lines), it carries only step 3's fields within their limits, the
  kickoff brief's first two lines are the template's, and the body has step
  4's interactive headings (`## Approval` only once Tim has accepted). What needs the orchestrator (`depends_on` ids, a repo the
  squad manages, intake `resources`) is checked by the submission; say which
  of these went unchecked.
- **Resume** with `/squad-planner <draft path>`. `Read` the draft, run step 1
  for its repo, and show Tim where it stands. A draft carrying `## Approval`
  was accepted: re-validate it and submit it as it stands through step 5's
  acceptance order, re-planning nothing; first look in the brief's `tasks`
  (and `squad://me`) for a task of the same title, and if one exists ask Tim
  whether this is a revision of it (`task_id`) before submitting. A draft
  without `## Approval` is a plan in progress: carry on drafting from it.
- **Submit later** when the squad was unreachable, either way: re-run
  `/squad-planner <draft path>` once the orchestrator is up (above); or, in
  the GUI at `http://127.0.0.1:7790`, Batches → New batch, upload the draft
  with the repository set to its `owner/name`. An upload enters as an intake
  task, and a plan equal to the intake frontmatter is approved without a
  review run.
- A draft stays after submission as Tim's record; he deletes it when done.

## Sibling planners

Interactive form. Several planner sessions may run at once, including ones
sweeping a backlog; there is no sweep mode or flag, so a backlog sweep is an
ordinary planner session with that description. The orchestrator holds the
record of what siblings are tackling, and Linear labels mirror it for people;
chat is never the record. No file on disk records a claim.

- **Reading.** At the start, and before taking any ticket, read
  `planning_claims` in the context brief (step 1): one entry per sibling
  planner session, with its `scope`, its `tickets` and when it last
  refreshed. `squad://me` shows this session's own. Tell Tim what siblings
  hold and keep clear of it. The orchestrator ages out the claim of a planner
  that stopped refreshing, so a claim in the brief is live; the planner does
  no staleness arithmetic of its own. The brief's `tasks` already cover work
  that has been planned and submitted.
- **Claiming.** At the settled point (step 2), call `mcp__squad__claim` with
  the repo, a one-line scope and the Linear ticket ids the plan takes. Refresh
  it with the same tool at every material plan update, in the same step as the
  PR and Linear update (this is also the heartbeat). Release it with
  `release: true` at acceptance (step 5) or when Tim abandons the plan. If the
  answer reports an overlap with a sibling's claim, stop and tell Tim, and
  proceed only on his word. If the tool is not offered (an orchestrator that
  predates it), say so, rely on the labels, and carry on.
- **Tickets, in Linear.** Taking a ticket into a plan applies the label
  `squad:planning`; acceptance replaces it with `squad:planned` (step 5).
  Before proposing work, exclude tickets labelled `squad:planning` or
  `squad:planned` and tickets in an in-progress state. Labels go through the
  Linear tools of the session; with none, tell Tim which tickets the planner
  would label, and carry on. A `squad:planning` ticket that no entry of
  `planning_claims` lists (its planner ended without accepting) is reported to
  Tim, and taken only with his say-so.
- **Messages** between planner sessions are a tie-break only, never the
  record.
