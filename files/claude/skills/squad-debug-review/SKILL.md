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

1. `squad debug list --json` gives one row per capture, newest first:
   `{date, first, last, members, deliveries, pause_resume_pairs, errors}`.
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

Transcripts are `~/.claude-{personal,exxo,exxo-personal}/projects/*/<session_id>.jsonl`.
`~/.claude-exxo-personal/projects` is a symlink to exxo's: dedupe by
resolved path (`realpath`) so nothing is read twice.

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
- The ask, **findings only, at most 80 lines**, no narrative of the process:
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

Do not re-do its reading yourself. If it returns more than 80 lines or
findings without evidence, send it back once via `SendMessage`.

## 5. Write `review.md`

Write `~/.local/state/squad/debug/<date>/review.md` (Write tool) with:

- **Summary**: window, members, headline numbers, the verdict in three
  sentences.
- **HITL interruptions** (first, before everything else): count, total and
  per-item wait, per-stream split; table of items (id, stream, raised,
  presented, resolved, wait); pre-emptable-in-preflight list; member-raised
  (unqueued) interruptions with transcript evidence; ranked reductions.
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
