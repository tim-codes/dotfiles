---
name: squad-debug-review
description: Review a squad debug-mode ensemble run — read the capture report and the orchestrator's decision log, have one investigator subagent comb the orchestrator and member transcripts, then write review.md with what worked, what was noise, missed or late reactions, wrong rulings and a ranked list of changes. Use the morning after a run started with `/squad-orchestrator --debug`, when Tim says "/squad-debug-review [date]", "review last night's squad run" or "what did the orchestrator get wrong".
argument-hint: "[YYYY-MM-DD]"
---

# Squad debug review

Turns one run's debug capture (`~/.local/state/squad/debug/<run>/`) into a
ranked list of improvements to the squad. Personal context only. Read-only
against the capture; the one file you write is `review.md` beside it.

State dir: `D=~/.local/state/squad/debug`. Env vars do not persist between
Bash calls: spell the paths out each time.

## 1. Pick the capture

A capture is filed under its run id, normally a date (`YYYY-MM-DD`, or
`YYYY-MM-DD-2` for a second run that day), not under each process's start
date. With a `[YYYY-MM-DD]` argument, use it as the run id (check `$D/<date>`
exists; if not, say so and fall to the picker). While capture is still on,
`squad debug dir` prints the current run's directory; use its basename.
Otherwise:

1. `squad debug list --json` gives one row per run, newest first:
   `{date, first, last, members, deliveries, pause_resume_pairs, errors}`.
   Each row is one run; its `date` field is the run id.
   Nothing listed: tell Tim there is no capture (was the orchestrator started
   with `--debug`, or `squad debug on` run?) and stop.
2. Ask with `AskUserQuestion`, one option per capture, newest first, at most
   4. Label = date + time window (local, from `first`..`last`); description =
   `<members> members, <deliveries> deliveries, <n> pause/resume pairs,
   <errors> errors`. The tool adds "Other" itself: say in the question text
   that Other takes an older date as `YYYY-MM-DD`.
3. Use the chosen run id for everything below (`<date>`).

The 2026-10-25 test run predates run ids: it lives in `debug/2026-10-24/`
(the baseline), with its events snapshot at `events-snapshot-20261025T0430Z`.
Pass `2026-10-24` for it.

## 2. Read the evidence

1. `squad debug report <date>` (add `--json` only if you need to compute on
   it). Read it in full: timeline, deliveries by member with p50/p95 latency
   and outcomes, candidate-noise turns, pause/resume pairs and whether the
   wall was hit anyway, projection ETAs vs actual, pressure episodes, watcher
   cadence, errors.
2. `$D/<date>/orchestrator-decisions.md` if present (blocks of `## <ts>
   <directive> → <member>` with reasoning and triggering seqs). Absent: the
   run was not `--debug` on the orchestrator side; note that, and the review
   rests on the report and transcripts only.
3. Window = `first`..`last` from the list row (the report header gives it
   too).

## 3. Locate the transcripts

Transcripts are `~/.claude-{personal,exxo,exxo-personal}/projects/*/<session_id>.jsonl`,
plus `~/.claude-exxo-openrouter/projects/*/<session_id>.jsonl` (the K3
context — a separate history, **not** a symlink into the others).
`~/.claude-exxo-personal/projects` is a symlink to exxo's: dedupe by
resolved path (`realpath`) so nothing is read twice.

Include each session's subagent transcripts, at
`~/.claude-*/projects/*/<session_id>/subagents/agent-*.jsonl` — attribute
their tokens to the session that launched them.

Also read, over the window (both always on, so they exist for every run):

- `~/.local/state/claude-openrouter/guard.jsonl` — the PreToolUse guard's
  block/allow decisions (`ts, session_id, cwd, rule, target, form,
  decision`); join to sessions on `session_id`.
- `~/.local/state/claude-openrouter/keyhelper.jsonl` — key-helper failures
  (`ts, reason`); any row in the window is an incident.

If `$D/<date>/openrouter.jsonl` is absent, run `squad debug openrouter
<date>` once to fetch the per-generation provider and cost records, then
re-check the file exists before going on.

- **Orchestrator**: `squad history orchestrator --limit 5`; take the newest
  gauge with `debug: true` and its `session_id`.
- **Members, live**: `squad roster` (`.req.name`, `.req.session_id`,
  `.req.account`).
- **Members, via registry**: `$CLAUDE_CONFIG_DIR/sessions/*.json` records
  (`pid`, `sessionId`, `cwd`, `name`) whose `cwd` matches a member seen.
- **Members gone since**: the `register` request lines in
  `$D/<date>/broker.jsonl`
  (`jq -c 'select(.op=="register")'`; inspect one line first to confirm the
  field names) carry each member's name and session id.

Resolve each id to a path with `ls ~/.claude-*/projects/*/<id>.jsonl`. Keep
a table `name, role, account, session_id, path`; flag ids with no file
(deleted or on another machine) rather than dropping them.

## 4. Dispatch one investigator

This skill's delegation policy: **one** subagent, nothing else. Announce the
roster line before launching: **1. Transcript review** (`investigator`) —
**sonnet**. Launch it with `Agent`, `subagent_type: investigator`,
`model: sonnet`. The brief must be self-contained (it has no context of
yours) and carry:

- The report text in full, the decision-log path, the transcript table
  (absolute paths), and the window.
- Mechanics: absolute paths only; read-only; transcripts are large JSONL, so
  filter with `jq`/`grep` to the window rather than reading whole files; do
  not print secrets or tokens.
- The ask, **findings only, at most 120 lines**, no narrative of the
  process. Sort every incident into exactly one of four quadrants —
  **worked**, **noise**, **missed or late**, **wrong or slow** — and give
  every incident row its evidence pointer (a transcript path plus record
  `uuid` and timestamp, or a capture file plus line `ts`):
  1. what worked (reactions that were correct and timely);
  2. turns that were noise (a `<squad-message>` delivered, no action taken);
  3. missed or late reactions (a quota wall hit despite a projection; a
     pressure episode with no `heavy_slot` revoke; a resume that came late);
  4. wrong or slow rulings (cite the decision-log block and the seqs);
  5. skill text that confused a member (a member asking what a message
     means, or mis-running a `squad` command; quote the line);
  6. numbers: deliveries, p95 latency, pause/resume count, wall hits.
  7. **HITL interruptions (the primary metric; put them first).** From
     `squad history operator` (the `operator` gauge) list each item with its
     raised/presented/resolved times and wait minutes. Say which could have
     been pre-empted in preflight (foreseeable at brief time); which were
     raised by a member directly instead of queued (grep the transcripts for
     auth prompts, `Touch ID`, `waiting for you`, browser-login steps); and the ranked changes that
     would remove or shorten them.
  8. **Deliverables.** Every deliverable named in a member's prompt (the
     plan's `deliverables`, orchestrator skill §3a) is delivered or
     tracked-deferred; list any that are neither.
  Every finding cites evidence: a log block, a seq, or a transcript path
  plus timestamp.

Do not re-do its reading yourself. If it returns more than 120 lines or
findings without evidence, send it back once via `SendMessage`.

## 5. Write `review.md`

Write `~/.local/state/squad/debug/<date>/review.md` (Write tool) with:

- **Summary**: window, members, headline numbers, the verdict in three
  sentences. If any anti-goal was breached, the first sentence says so.
- **HITL interruptions** (first, before everything else): count, total and
  per-item wait, per-stream split; table of items (id, stream, raised,
  presented, resolved, wait); pre-emptable-in-preflight list; member-raised
  (unqueued) interruptions with transcript evidence; ranked reductions.
- **K3 efficacy** (pass/fail table, one row per criterion):
  - job success: `ok/finished` ≥ 80% passes, < 60% fails (between: judgement
    call, explained);
  - rework: `rework+rejected/reviewed` ≤ 25% passes, > 40% fails;
  - cost: median per job ≤ $1.50 and none above $10 passes, otherwise
    fails;
  - wall time: median ≤ 50% of deadline and timeouts ≤ 10% passes,
    timeouts > 20% fails;
  - cache reads ≥ 50% of input tokens from each session's third turn
    passes, < 25% fails;
  - review pool share ≥ 50% of the run's reviews on K3 — reported, not
    gated;
  - tokens moved off Anthropic — reported, not gated.
- **K3 issues register** (pass/fail table): zero anti-goal breaches; zero
  silent fallback (a K3 job that quietly ran on a Claude account); zero
  `wrong` denials or guard blocks that stopped a job (join
  `~/.local/state/claude-openrouter/guard.jsonl` to jobs on
  `session_id`); every 402 ended `failed/budget`; every issue class listed
  in full and every `unclear` verdict explained.
- **Round changes: efficacy** (pass/fail table; each change against the
  defect it targeted, with the baseline value in brackets):
  - ENG-339 delivery: max hold age while busy ≤ `max_hold_seconds` + one
    tick (baseline: 44 held `next` messages); every crossed level
    delivered to each matching subscriber (75 and 90 together at 92%, no
    85); zero duplicate `joined` (two per builder); ack-gated directive
    p95 delivery ≤ 5 s;
  - ENG-337: every approval item has a `decision`, and denials and items
    join 1:1 (baseline: a denial lost; Approve recorded nothing);
  - ENG-338: every merge by a grant holder or infra, zero denied merges
    retried, zero K3 merges;
  - ENG-340: burn noticed (decision or operator line) within 15 min of
    `burn started` (baseline: about £3 burnt unnoticed in 15 min);
  - herder split: zero tmux calls in the concierge transcript, every
    launch and close in `history.jsonl`, zero unreported
    `close_mismatch`;
  - federation: every job reaches a terminal state or is in flight at run
    end, no requester waits beyond a deadline, queued→assigned p95 ≤ 5
    min while a capable worker is free;
  - rate-aware pausing: every rate-aware directive has a trigger, no wall
    hit after a `walls_before_reset` projection made 30+ min earlier;
  - host: at most one pressure flap per 15 min;
  - capture: one run dir holds every sink and log.
- **Round changes: issues**: for each change, every regression or new
  failure mode it caused (e.g. a `max_hold` flush interrupting a turn, an
  ack bypass storm, a herder relaunch loop, a job leaking a worktree),
  with evidence; plus one rubric row each for:
  - liaison: every liaison action checked against the per-client policy —
    a send to a non-`act` client, a send as tim@ without
    `send_as = "tim"`, or a rate-limit breach is an incident (audit:
    `$D/<date>/mail.jsonl` and `<state>/mail/audit.jsonl`, decisions in
    `$D/<date>/liaison-decisions.md`);
  - rebalancing: every rebalance has a trigger and an outcome recorded; a
    move without a decision-log block is an incident; judge each proposal
    `correct` / `wrong` / `unclear`;
  - batched trunks: every trunk test run attributed, and every attributed
    failure counted — a member's comprehensive run without a slot, a
    landing on red, or a commit unlanded for more than 8 h is an
    incident.
- **Baseline comparison**: the same metrics for the 2026-10-25 run
  (Claude only), computed by `squad debug report 2026-10-24 --from <first
  orchestrator decision> --until <wind-down>` over the frozen events
  snapshot (`$D/2026-10-24/events-snapshot-20261025T0430Z`). Metrics for
  both runs: deliveries, p50/p95 delivery latency, max hold age,
  crossings published vs delivered per level, duplicate joins, HITL items
  and wait, denials (and retries), wall hits, pause/resume pairs, exxo
  five-hour %/h, extra usage burnt, Anthropic tokens by model including
  subagents, and merged PRs, with Anthropic tokens per merged PR as the
  normalised comparison.
- **What worked**.
- **Findings** (non-HITL): grouped as noise, missed/late, wrong rulings,
  confusing skill text; each with its evidence.
- **Ranked change list**, best benefit-for-cost first; changes that cut
  HITL interruptions rank ahead of equal-cost others. Each item:
  *change*; *where* (one of: code — which crate/module; skill text — which
  skill and section; config threshold — which key and from/to values);
  *cost* S/M/L; *benefit*; *evidence* (finding reference). Prefer fixes in
  skill text and thresholds over code when they would do.

Do not edit anything outside `review.md`; the changes are proposals.

## 6. Present and offer issues

Show Tim the ranked list in chat (table: rank, change, where, cost,
benefit), the `review.md` path, and the three biggest findings in a line
each. Then ask with `AskUserQuestion` whether to file the top items as
GitHub issues in `tim-codes/squad` (options: top 3, top 5, none; Other for a
chosen set). Only on a yes: for each item
`gh issue create -R tim-codes/squad --title "<change>" --body "<where, cost,
benefit, evidence, review.md path and date>"`, then list the issue URLs.
Never file without the yes.
