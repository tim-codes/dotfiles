---
name: squad-debug-review
description: Use after an unattended squad v0.5 round, when Tim says "/squad-debug-review [run]", "review last night's squad run", "what did the leader have to do by hand" or "rank the changes from that run", or when a leader's round wrap-up launches the review lane. Reviews one run from its review bundle (or, when none can be produced, read-only Postgres) and writes review.md.
argument-hint: "[run]"
---

# Squad debug review

Turns one squad v0.5 run into a ranked list of changes. Shared to every
context. Read-only against the squad: the files you write are `review.md`
beside the bundle and, when the brief asks, a copy in the squad repo on a
branch with a PR.

**Terms.** The *orchestrator* is the v0.5 TypeScript service (policy, items,
trunk service, tRPC). The *broker* is the Rust daemon. The *leader* is the
temporary operator Claude session that keeps the squad moving by hand; it is
not part of the squad design, and everything it did by hand is a capability
the squad is missing. Never call the leader "the orchestrator".

**Inputs.** The review bundle at
`~/.local/state/squad/debug/<run>/bundle/` is the primary input. Transcripts
are second: open one only for an incident the bundle already names. Env vars
do not persist between Bash calls; spell paths out each time.

## 1. Pick the run

With a `[run]` argument, use it. Otherwise:

1. `squad debug list` (one row per `runs` row: id, mode, window, events,
   decisions, interventions, bundle present). Until the attended rebuild
   ships that CLI, read the orchestrator's `runs.live` / `runs.list` through
   tRPC (cookie from `GET http://127.0.0.1:7790/auth/local`, local only) and
   `ls -t ~/.local/state/squad/debug/`.
2. Attended: ask with `AskUserQuestion`, newest first, at most 4 options,
   label = run id + window, description = mode, events, interventions.
   Unattended (the brief names the run, or nobody will answer): take the
   newest run that has ended, and say so in the summary.
3. The *previous run* is the next-older row; its bundle gives the trend
   columns. No previous bundle: say "no trend" in those sections rather than
   recomputing one by hand.

## 2. Produce the bundle

```bash
squad debug bundle <run>                                          # after the attended rebuild
just -f /Users/tim/dev/squad/orchestrator/Justfile bundle <run>   # today; same files
ls ~/.local/state/squad/debug/<run>/bundle/
```

Expected files: `run.json`, `summary.md`, `timeline.md`/`.jsonl`,
`tasks.csv`, `deliveries.csv` + `latency.md`, `idle.csv`, `heavy.csv`,
`lands.csv`, `items.csv`, `interventions.csv`, `quota.md`, `host.md`,
`watches.csv`, `sessions.csv`, `usage.csv`, `errors.jsonl`,
`decisions.jsonl`, `events.jsonl.gz`. A missing file is a capture-readiness
finding (section 5), not a reason to stop.

Also read, if present, the leader's pre-v0.5.10 intervention log
`~/.local/state/squad/debug/<run>/interventions.jsonl` (shape in the
`squad-leader` skill); merge it with `interventions.csv` and label the rows
`leader-file`.

**Fallback: no bundle can be produced** (orchestrator down, recipe absent,
run predates v0.5.10). Query Postgres read-only through
`just -f /Users/tim/dev/squad/deploy/Justfile psql` over `events`,
`decisions`, `operator_items`, `inbox`, `trunk_lands`, `heavy_requests`,
`session_usage`, `sessions` with the window from `runs` (or, before `runs`
exists, from the first and last event of the day). Queries in
[references/postgres-fallback.md](references/postgres-fallback.md); save
each result as a TSV in your scratchpad, named after the bundle file it
stands in for (`items.tsv`, `interventions.tsv`, …), and hand those paths
to the investigator in place of the bundle. The summary's evidence line
then says **"Evidence: Postgres fallback, no bundle"**, and every number is
labelled as hand-computed. Never write to the database.

## 3. Read before delegating

Read `summary.md`, `run.json`, `interventions.csv` and `items.csv` yourself:
they decide the shape of the review. Then build **what shipped since**: the
previous review's ranked list (issues labelled `debug-review:<previous run>`
in `tim-codes/squad`: `gh issue list -R tim-codes/squad --label <label>
--state all`) against `run.json` versions and the CHANGELOG sections between
the two runs. Note broker changes that are merged but not in the running
binary (`run.json.versions.broker` versus the CHANGELOG Rollout lines): a
fix that was not live cannot be judged this run.

## 4. Dispatch one investigator

Exactly **one** subagent, nothing else. Roster line before launching:
**1. Bundle and transcript review** (`investigator`) — **sonnet**. Launch
with `Agent`, `subagent_type: investigator`, `model: sonnet`. The brief is
self-contained and carries:

- The absolute bundle dir, the window, the file list with what each holds
  (section 2), and the terms paragraph above (leader versus orchestrator).
- Mechanics: absolute paths; read-only; bundle first. Transcripts
  (`sessions.csv` column `transcript_path`, with `transcript_exists`) are
  opened only for an incident already cited from a bundle file, filtered
  with `jq`/`grep` to the window; subagent transcripts live beside the
  parent under `<session_id>/subagents/`. One exception: asks 1 and 8 may
  run a single `grep` sweep over the member transcripts listed in
  `sessions.csv` for fixed patterns (`Touch ID`, `waiting for you`,
  browser-login steps, `invalid_input`, "what does this message mean"),
  then read only the hits. No secrets or tokens in the report.
- The ask, **findings only, at most 120 lines**, each with an evidence
  pointer (`bundle/<file>:<line>`, a `decisions.jsonl` id, or a transcript
  path plus record `uuid` and timestamp). Sort every incident into one of
  **worked**, **noise**, **missed or late**, **wrong or slow**, and report:
  1. HITL items (`items.csv`): per source (preflight, raised, policy) the
     count, p50/p95 wait, who decided (actor label), which were foreseeable
     at brief time, which never notified anyone
     (`operator.notify_skipped`), raise refusals (`invalid_input`), and any
     unqueued prompt in a member transcript (`Touch ID`, browser login,
     permission prompt).
  2. Leader interventions (`interventions.csv` plus the file log): count per
     function L1–L13, each refusal the leader met and what it did
     (`outcome`: done, parked, handed_to_tim), any routed-around refusal
     (a nested session, a re-run of a denied command: always an incident).
  3. Idle stretches (`idle.csv`) over 10 min with their wait reason or none;
     heavy waits (`heavy.csv` `waited_s`) p50/p95 and the top members.
  4. Lands (`lands.csv`): landed, refused by `reason_code`, review time,
     wrong-base or force-push incidents.
  5. Delivery (`deliveries.csv`): p50/p95/max `wait_s`, `mid_turn` share,
     undelivered to closed sessions, directives never acked.
  6. Watches, quota, host, errors (`watches.csv`, `quota.md`, `host.md`,
     `errors.jsonl`): dead watch kinds, walls, pressure episodes, restarts
     (`run.json.restarts`) with build outcome and downtime.
  7. Deliverables: every plan deliverable (`tasks.csv`) delivered, or
     tracked as an item or issue; list what is neither.
  8. Skill text that confused a member (a member asking what a message
     means, a tool call refused for shape, a refusal text followed by the
     wrong action); quote the line and the transcript pointer.
  9. Only if `usage.csv` has rows with account `openrouter`: per session
     the served model, cost, failures and any silent fallback.

Do not redo its reading. More than 120 lines, or findings without evidence:
send it back once with `SendMessage`.

## 5. Write `review.md`

`~/.local/state/squad/debug/<run>/review.md` (Write tool), sections in this
order. Where the bundle computed a number, cite the file; where you did,
say so. Section-to-column map and the carried-over pass/fail targets in
[references/review-sections.md](references/review-sections.md).

1. **Summary**: run id, window, mode, versions, the evidence line (bundle,
   or the fallback sentence) as the section's first line, the headline
   table from `summary.md`, then the verdict in three sentences. An
   anti-goal breach (an unauthorised merge, a secret logged, the live stack
   broken) is the verdict's first sentence.
2. **What shipped since**: previous ranked list, each item shipped / live /
   merged-not-live / open.
3. **HITL interruptions**: counts and waits per source, clusters with
   foreseeability, notification gaps, raise friction, unqueued prompts, what
   Tim actually did and when.
4. **Leader interventions**: a table L1–L13 with this run's count, the
   previous run's count, the trend arrow, and the issue that retires the
   function (table in the `squad-leader` skill's references). Then each
   refusal met and how it was handled; a routed-around refusal is a finding
   under wrong rulings.
5. **Capture readiness**: was the run recorded by the orchestrator (a
   `runs` row with the right mode) or only by the broker sinks; who switched
   it on and when; bundle files missing or empty; `transcript_exists` false
   counts; broker version versus merged-not-live changes.
6. **Delivery, idle, heavy, lands, quota and host**: the numbers from items
   3 to 6 above, each with its previous-run value.
7. **Round changes: efficacy**: one row per change merged since the previous
   run, judged on the evidence column its PR named ("Evidence:" in the PR
   body or CHANGELOG bullet): pass / fail / not live / **no evidence named**
   (itself a finding). New failure modes a change caused, with evidence.
8. **What worked**.
9. **Findings**: noise; missed or late; wrong rulings (orchestrator policy
   and leader alike, each `correct` / `wrong` / `slow` / `unclear` with the
   ruling id or `managed_repos` row it should have cited); confusing skill
   or message text; deliverables neither delivered nor tracked.
10. **K3** only when item 9 returned rows; otherwise one line: "no
    openrouter sessions this run".
11. **Ranked change list**, best benefit for cost first; changes that remove
    a HITL interruption or retire a leader function rank ahead of equal-cost
    others. Columns: *change*; *where* (code: which module; skill text: which
    skill and section; config: which key, from/to); *cost* S/M/L;
    *benefit*; *evidence* (finding id); *evidence next round* (the bundle
    column that will show it worked).

Write nothing else into the squad state dir. When the brief asks for a copy
in the repo: a branch off the squad trunk in its own worktree
(`wt -C /Users/tim/dev/squad switch --create docs/debug-review-<run> --base origin/trunk/v0.5 --no-cd -y`),
file `docs/superpowers/plans/<date>-squad-debug-review-<run>.md`, draft PR
with the brief's trailers. Never commit to `main`.

## 6. Present and offer issues

Attended: show the ranked list in chat (rank, change, where, cost, benefit),
the `review.md` path and the three biggest findings in a line each. Then
ask with `AskUserQuestion` whether to file the top items as GitHub issues in
`tim-codes/squad` (top 3, top 5, none; Other for a chosen set). Only on a
yes: `gh issue create -R tim-codes/squad --title "<change>" --label
"debug-review:<run>" --body "<where, cost, benefit, evidence, review.md
path>"` (prefix the title with `[<run>]` when the label does not exist and
cannot be created), then list the URLs.

Unattended (nobody to answer, or the brief says so): file nothing, and end
the report with "issues not filed: unattended; ranked list in review.md".

## Common mistakes

- Reading transcripts first. The bundle holds most of what transcripts
  confirm; the 2026-10-31 review read 143 transcripts to learn what
  `events` already said.
- Calling the leader's workaround a fix. A nested session that re-runs a
  denied command, a hand merge, a hand-run render: each is an intervention
  to retire, never a solution to recommend.
- Judging merge authority from prose. Merge scope is
  `managed_repos.release_needs_approval` (true only for h2gc-portal and
  h2gc-legacy); cite the row, not a rulings paragraph.
- Blaming a fix that was not live. Check `run.json.versions.broker` before
  marking a broker change failed.
- Filing issues without the yes, or in an unattended session.
