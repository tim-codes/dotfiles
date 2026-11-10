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
are second: open one only for an incident the bundle already names, plus
the two fixed-pattern sweeps in section 4. Env vars do not persist between
Bash calls; spell paths out each time.

**State dir layout.** A `runs` row's bundle is `debug/<run id>/bundle/`; a
window bundle is `debug/window-<from>/bundle/`; older captures (the
broker's `host.jsonl`/`quota.jsonl` sinks, an earlier `review.md`, the
leader's `interventions.jsonl`) sit in the dated dir `debug/<YYYY-MM-DD>/`.
When a window bundle covers a day that has a dated dir, read the sinks and
the leader's file there; a `review.md` in it is read and linked **only if
its mtime is before the window start**, otherwise it is probably this
run's own hand review and leaks the conclusions. Never overwrite one.

**Authority inputs.** The bundle's `repos.csv` (the `managed_repos`
snapshot with `release_needs_approval`) and the leader's rulings memory,
read-only: in the leader's memory directory
(`projects/-Users-tim-claude/memory/tim-rulings-*.md` under its account context) and
`unattended-delegate-watch.md`, or whatever files the round's handover
brief names. Every merge into a `release_needs_approval` repo and every
leader workaround is judged against the ruling it cites.

**Commands.** The `bundle` and `debug-runs` recipes live in the squad
primary checkout `/Users/tim/dev/squad` once v0.5.10 is on `main`; run them
from there (`just -f /Users/tim/dev/squad/orchestrator/Justfile --list`
shows whether they exist; before that, the v0.5.10 release worktree has
them). Until the attended broker rebuild the installed `squad debug list`
is the old capture-folder list, not runs: do not use it.

## 1. Pick the run

With a `[run]` argument, use it. Otherwise:

1. `just -f /Users/tim/dev/squad/orchestrator/Justfile debug-runs [limit]`
   (loopback `GET /debug/runs`: one row per `runs` row with id, mode,
   window, events, decisions, interventions, bundle present), or the BFF
   `runs.list` / `runs.current` (`GET http://127.0.0.1:7780/bff/runs.list`,
   cookie from `GET http://127.0.0.1:7780/auth/local`, local only). After the attended
   rebuild `squad debug list` prints the same rows. A run before the `runs`
   table has no row: it is bundled from a window (section 2).
2. Attended: ask with `AskUserQuestion`, newest first, at most 4 options,
   label = run id + window, description = mode, events, interventions.
   Unattended (the brief names the run, or nobody will answer): take the
   newest run that has ended, and say so in the summary.
3. The *previous run* is the newest run row, capture dir or `review.md`
   that ended **strictly before this window started**; never one from the
   same date or window (that is this run's own hand review). Its bundle
   gives the trend columns; its `review.md` or issue gives the previous
   ranked list. No previous bundle: say "no trend" in those sections rather
   than recomputing one by hand.

## 2. Produce the bundle

```bash
squad debug bundle <run>                                             # after the attended rebuild
just -f /Users/tim/dev/squad/orchestrator/Justfile bundle <run>      # today; same files
just -f /Users/tim/dev/squad/orchestrator/Justfile bundle '' 2026-10-31T05:00Z 2026-11-01T03:00Z   # window mode
ls ~/.local/state/squad/debug/<run>/bundle/
```

**Window mode** is the first choice for a run that predates the `runs`
table (anything before v0.5.10, such as 2026-10-31): `bundle '' <from>
<until>` with ISO 8601 UTC bounds. The bundle id is `window-<from>` with
the colons and milliseconds removed, so the example above writes
`~/.local/state/squad/debug/window-2026-10-31T050000Z/bundle/`; use that
id as `<run>` everywhere below. The route caps a window at 7 days; a
larger one takes the fifth argument `flags` (space-separated `direct`
and/or `large`): `bundle '' <from> <until> '' 'direct large'` bundles
directly with `--allow-large`.

The recipe (`bundle [run] [from] [until] [out] [flags]`) asks the running
orchestrator (loopback `POST /debug/bundle`) and, when it is down or
predates the route, runs the bundler itself; no broker rebuild is needed.
Expected files: `run.json`, `summary.md`, `timeline.md`/`.jsonl`,
`tasks.csv`, `deliveries.csv` + `latency.md`, `idle.csv`, `heavy.csv`,
`lands.csv`, `items.csv`, `interventions.csv`, `quota.md`, `host.md`,
`watches.csv`, `sessions.csv`, `usage.csv`, `errors.jsonl`,
`decisions.jsonl`, `events.jsonl.gz`. A missing file is a capture-readiness
finding (section 5), not a reason to stop.

`interventions.csv` is already complete: the bundler merges
`leader.intervention` events (`source` = `explicit`), `gui:leader`
mutations (`inferred`), unlabelled `gui` mutations and operator inbox notes
(`inferred-unlabelled`: the leader or Tim, indistinguishable) and the
leader's `<run>/interventions.jsonl` (`leader-file`). Never merge that file
again, it double counts. Coverage tagging marks an inferred row that an
explicit record already describes as `covered`, so the KPI counts each
intervention once; `inferred-unlabelled` rows are reported but left out of
the L1–L13 trend.

**Fallback: no bundle can be produced**, only when the bundler itself
cannot run (no orchestrator checkout, Postgres down; a pre-v0.5.10 run is
not a reason, window mode covers it). Query Postgres read-only through
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
they decide the shape of the review. Decide now whether the **leader
sweep** applies: it does when `interventions.csv` has few or no `explicit`
or `leader-file` rows (every run before v0.5.10, or a leader that did not
call `intervene`). Identify the leader session(s) as
[references/leader-sweep.md](references/leader-sweep.md) says and put
their ids, transcript paths and scratchpad dir in the brief. Read
`repos.csv` and the rulings memory now and list, for the brief, the
`release_needs_approval` repos and the ruling ids that sanction a
workaround or a merge (e.g. a "for today" merge-runner ruling).

Then build **what shipped since** (when the previous run ran a different
major version, list only the previous ranked list's status and skip the PR
sweep):

- The previous ranked list: issues labelled `debug-review:<previous run>`
  when that label exists; otherwise `debug/<previous run>/review.md`
  section 11, or the squad issue titled "fixes from the <previous run>
  debug review". Never read issues created after the window ended: they
  may be this run's conclusions, filed from a hand review.
- Each change merged since the previous run, in three groups from the PR's
  `mergedAt` (`gh pr list -R <repo> --state merged --search "merged:<prev
  end>..<window end>" --json number,title,mergedAt`) and the CHANGELOG:
  **before the window**; **in-window and live** (an orchestrator restart
  followed the merge: `run.json.restarts`, or `errors.jsonl`/the leader
  sweep when restarts are empty); **in-window, not live** (broker changes
  behind the attended rebuild per the CHANGELOG Rollout lines, or no
  restart after the merge). A fix that was not live cannot be judged this
  run.

## 4. Dispatch one investigator

Exactly **one** subagent, nothing else. Roster line before launching:
**1. Bundle and transcript review** (`investigator`) — **sonnet**. Launch
with `Agent`, `subagent_type: investigator`, `model: sonnet`. The brief is
self-contained and carries:

- The absolute bundle dir, the window, the file descriptions (pass the
  absolute path of this skill's `references/review-sections.md`, or inline
  its table), and the terms paragraph above (leader versus orchestrator).
- Mechanics: absolute paths; read-only; bundle first. Transcripts
  (`sessions.csv` columns `transcript_path`, `transcript_exists`,
  `transcript_found_via`) are opened only for an incident already cited
  from a bundle file, filtered with `jq`/`grep` to the window; a missing
  transcript is searched only under the roots named in
  `references/leader-sweep.md` (pass that file's path), never with
  `find /`. Two fixed-pattern sweeps are the exceptions: asks 1 and 8 may
  grep the member transcripts once (`Touch ID`, `waiting for you`,
  browser-login steps, `invalid_input`, "what does this message mean") and
  read only the hits; ask 10 is the leader sweep; ask 11 is three targeted
  checks. The bundle's zeros are not trusted: before reporting a `0`,
  `n/a`, "not recorded" or "capture was off" for restarts, closed
  sessions, tunnel loss, build failures, undelivered messages, mid-turn
  share, headroom or wrong-base lands, read `logs.md` (notable operational
  log lines) and `run.json`'s capture facts, then cross-check
  `events.jsonl.gz` and `errors.jsonl`, and say which won. No secrets or
  tokens in the report.
- The ask, **findings only, at most 140 lines** (ask 9 and 10 only when
  their condition holds), each with an evidence
  pointer (`bundle/<file>:<line>`, a `decisions.jsonl` id, or a transcript
  path plus record `uuid` and timestamp). Sort every incident into one of
  **worked**, **noise**, **missed or late**, **wrong or slow**, and report:
  1. HITL items (`items.csv`): per source (preflight, raised, policy) the
     count, p50/p95 wait, who decided (actor label), which were foreseeable
     at brief time, which never notified anyone
     (`operator.notify_skipped`), raise refusals (`invalid_input`), and any
     unqueued prompt in a member transcript (`Touch ID`, browser login,
     permission prompt).
  2. Leader interventions (`interventions.csv`): count per function L1–L13
     and per `source` (`inferred-unlabelled` counted apart: the leader or
     Tim), each refusal the leader met and what it did (`outcome`: done,
     parked, handed_to_tim), any routed-around refusal (a nested session, a
     re-run of a denied command: always an incident).
  3. Idle stretches (`idle.csv`) over 10 min with their wait reason or none;
     heavy waits (`heavy.csv` `waited_s`) p50/p95 and the top members.
  4. Lands (`lands.csv`): landed, refused by `reason_code`, review time,
     force-push incidents; and for **every landed PR**
     `gh pr view <n> -R <repo> --json baseRefName,mergedBy`, flagging a
     base that is not the repo's trunk policy (`lands.csv` has no base
     column; the 2026-10-31 land of squad#243 on `main` was invisible
     without this) and a `mergedBy` that is not the squad's GitHub App.
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
  10. Only when section 3 said the leader sweep applies: the fixed-pattern
      sweep of the named leader transcript(s) and scratchpad from
      `references/leader-sweep.md`, reported as a table of counts per
      L1–L13 with one pointer each plus the refusal list, **at most 30
      lines** of the 140.
  11. Three incident classes the bundle cannot flag, one targeted
      transcript check each (method in `references/leader-sweep.md`,
      "Targeted checks"): a wind-down sent before the land reached
      `landed`; an item decided whose member was never told; a heavy grant
      followed by a Bash gate refusal.

Do not redo its reading. More than 140 lines, or findings without evidence:
send it back once with `SendMessage`.

## 5. Write `review.md`

`~/.local/state/squad/debug/<run>/review.md` (Write tool), sections in this
order. Where the bundle computed a number, cite the file; where you did,
say so. Section-to-column map and the carried-over pass/fail targets in
[references/review-sections.md](references/review-sections.md).

1. **Summary**: run id, window, mode, versions, the evidence line (bundle,
   or the fallback sentence) as the section's first line, the headline
   table from `summary.md`, then the verdict in three sentences. An
   anti-goal breach is the verdict's first sentence. **Anti-goals** (v0.5
   spec §9 plus the `managed_repos` merge scope): a merge outside
   authority (a `release_needs_approval` repo, h2gc-portal and h2gc-legacy,
   merged without Tim's decision); anything touching h2gc prod (the spec's
   approval-required and operator-only stacks); a secret leaked into
   events, a bundle, a log or a PR; a classifier or permission refusal
   routed around **without a ruling**. Judge each candidate against the
   authority inputs: a workaround Tim explicitly sanctioned (a dated
   ruling such as a "for today" merge-runner) is a leader function to
   retire (section 4), not a breach; a merge into a
   `release_needs_approval` repo is a breach only if no ruling covers it,
   otherwise it is flagged for Tim with the ruling id. A wrong-base land,
   a bad restart or an outage is a failure mode (section 7 or 9), not an
   anti-goal, unless it bypassed authority.
2. **What shipped since**: the three groups from section 3; each item of
   the previous ranked list shipped / live / merged-not-live / open.
3. **HITL interruptions**: counts and waits per source, clusters with
   foreseeability, notification gaps, raise friction, unqueued prompts, what
   Tim actually did and when.
4. **Leader interventions**: a table L1–L13 with this run's count
   (`explicit` + `inferred` + `leader-file`), the previous run's count
   (`summary.md` already computes both from the previous bundle), the
   trend arrow, and the issue that retires the function (table in
   `../squad-leader/references/leader-functions.md` beside this skill's
   directory); `inferred-unlabelled` rows in a
   separate line, outside the trend; when the leader sweep ran, its counts
   as a `transcript-sweep` line, with the functions that rest on it alone
   named. Then each refusal met and how it was handled; a routed-around
   refusal is a finding under wrong rulings.
5. **Capture readiness**: was the run recorded by the orchestrator (a
   `runs` row with the right mode) or only by the broker sinks; who switched
   it on and when (`run.json` capture facts, `logs.md`, the leader sweep's
   `squad debug on` hits: "nobody switched it on" needs all three empty);
   bundle files missing or empty; `transcript_exists` false counts; broker
   version versus merged-not-live changes.
6. **Delivery, idle, heavy, lands, quota and host**: the numbers from items
   3 to 6 above, each with its previous-run value.
7. **Round changes: efficacy**: one row per change merged since the previous
   run, grouped as in section 3, judged on the evidence column its PR named
   ("Evidence:" in the PR body or CHANGELOG bullet): pass / fail / not live.
   When no PR names one, judge against the column
   `references/review-sections.md` maps to that kind of change and mark the
   row **no evidence named** (itself a finding). Before citing a `0`,
   `n/a` or "not recorded" rubric row, cross-check it against
   `events.jsonl.gz` and `errors.jsonl` and say so. New failure modes a
   change caused, with evidence.
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
in the repo: a branch off `main` (squad lands on `main`) in its own worktree
(`wt -C /Users/tim/dev/squad switch --create docs/debug-review-<run> --base origin/main --no-cd -y`),
file `docs/superpowers/plans/<date>-squad-debug-review-<run>.md`, draft PR
with the brief's trailers. Never commit to `main`.

## 6. Present and offer issues

Attended: show the ranked list in chat (rank, change, where, cost, benefit),
the `review.md` path and the three biggest findings in a line each. Then
ask with `AskUserQuestion` whether to file the top items as GitHub issues in
`tim-codes/squad` (top 3, top 5, none; Other for a chosen set). Only on a
yes: create the label if it is missing (`gh label create
"debug-review:<run>" -R tim-codes/squad`), then for each item
`gh issue create -R tim-codes/squad --title "<change>" --label
"debug-review:<run>" --body "<where, cost, benefit, evidence, review.md
path>"` (prefix the title with `[<run>]` if the label cannot be created),
then list the URLs.

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
- Copying the bundle's zeros. "0 restarts", "0 undelivered" and "not
  recorded" have each been wrong; cross-check events and errors first.
- Skipping the leader sweep on a run with unlabelled interventions: the
  leader's merges, refusals, restarts and releases then all read zero.
- Reading issues filed after the window ended, or this run's own hand
  review, before writing: they leak the conclusions.
- Filing issues without the yes, or in an unattended session.
