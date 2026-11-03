# Leader functions L1–L13 and what retires each

Taxonomy from the 2026-10-31 debug review §3 (tim-codes/squad,
`docs/superpowers/plans/2026-10-31-squad-v05-debug-review.md`), pinned in
the orchestrator's `leader.intervention` contract. Log every instance with
`intervene` (or the file log) using the function id. Counts in brackets are
the 2026-10-31 baseline the next rounds are measured against.

| # | Function | What the leader does by hand today | Retired by | Log as |
|---|---|---|---|---|
| L1 | Unblock classifier and permission refusals [about 18] | Hands the refused action to Tim with the exact command; files the squad issue that removes the need. Not logged as its own row: a refusal is logged under the function it blocked (L2, L3, L9, …) with `outcome: handed_to_tim`, and L1 is the count of those rows | #287 (trunk service owns merges and issue close-out), #288 (host-job for sandbox-blocked commands); items carry an exact one-line command | the blocked function, `outcome: handed_to_tim`, `command` |
| L2 | Merges outside the trunk service [27] | Merges framework and release PRs with its own `gh pr merge` when permitted (logged, `outcome: done`); when the classifier refuses, the PR goes to Tim (`handed_to_tim`). Milestones are Tim's by default (`policy:land:<task>:milestone:<id>`). The nested merge-runner (ruling 38) is retired | #287; milestones stay by hand (v0.5.14) | `pr`, `reason` citing `managed_repos` |
| L3 | Run sandbox-blocked work unsandboxed [75 renders, 13 items] | Runs an allow-listed render or repo gate script (`verify.sh`, `format.sh`, `node --check`) outside the member sandbox and returns the result to the member by `inbox.send` | #288 (broker host-job with a fixed allowlist); Node 24 pinned for members | `member`, `task_id`, `command` |
| L4 | Decide items [59] | `items.decide` under a ruling it can cite | #290 (rulings in the DB, routine kinds auto-decided) | `item_id`, `reason: ruling <id>` |
| L5 | Brief members [61 notes] | `inbox.send` a note: a fix landed, a new ruling, a protocol change; a nudge only in answer to a `stuck-<m>` item | #290 (ruling broadcast); idle nudges retired by supervision (v0.5.14, ENG-505) | `member`, `task_id`, `item_id` |
| L6 | Session control | `sessions.resume` after a restart or a refused land; `sessions.close` a revived idle session; a policy pause | #291 (resume lost and refused-land sessions after restart), #285 | `member`, `session_id` |
| L7 | Rebuild and restart [10 orchestrator, 2 broker] | `deploy/ops.Justfile restart-orchestrator` (fallback: procedures.md) | #291 (verified release and restart job); #292 keeps only the attended broker re-grant | `reason`, `command` |
| L8 | Cut squad releases and tags [6] | Release PR squash-merged onto squad `main` (`direct`), tag; one re-run of a transiently failed release job. Product releases on `release_kind = tag` repos are the orchestrator's (v0.5.14, ENG-522) | #293 (release task kind) | `pr`, `command` |
| L9 | File and close issues [11 filed, 20 closes] | `gh issue create/close -R tim-codes/squad`; refused closes go to Tim | #287 (closes `Closes #n` at land); members raise bugs as items the orchestrator files | `command` |
| L10 | Hygiene [35 worktrees, 20 windows] | `worktree-closedown` skill; tmux windows by name or `@id` | #239 (teardown at land; partial) plus transcript relocation in the trunk service | `task_id` |
| L11 | Plan and approve rounds [7 approvals, 3 planner lanes] | Launches a planner lane over open issues; `tasks.approve` under ruling 29 | #294 (when-idle planning under standing rulings); agentic plan review already live | `task_id`, `reason: ruling 29` |
| L12 | Operator-only legs [15 decks, 15 Slack sends] | Figma, Boards, Slack, Notion, Linear legs members cannot reach | #295 (Figma and Boards via `needs`/`provides`; concierge sends status and pairing links) | `task_id`, `item_id` |
| L13 | Watch for trouble [1,137 monitor events] | The watch list in the skill's Operating section (items, activity line, dependency strip, tunnel, quota) | supervision, deps watcher and doctor rows (v0.5.14); #286 (CI-green watch kind), ENG-513 (orchestrator alerting) | one row per monitor-triggered action, not per poll |

Look a title up with `gh issue view <n> -R tim-codes/squad`. When an issue
closes, the function is retired only once a round's `interventions.csv`
shows zero for it; until then it stays in the table with the new count.

## What the orchestrator does on its own (v0.5.14): not the leader's job

Each of these was a hand-done intervention in the 2026-11-02/03 round. Doing
it by hand now duplicates the orchestrator and hides whether it worked.

- **Idle members.** Supervision (`[policy.supervision]`) nudges a member
  idle 10 min with nothing to wake it, nudges again after 10 more, then
  raises `stuck-<member>` (`blocking: now`); a silent `running` session with
  a heavy grant or a Bash call in flight is escalated, never interrupted.
  Do not hand-nudge. Act only on a `stuck-<m>` item, after reading the
  activity line and the mirror log.
- **Blocked members.** A member going `blocked` promotes its own items to
  `blocking: now` or raises `blocked-<member>`. Do not rank or re-flag items.
- **The secret cache.** The deps watcher (`[policy.deps]`) starts OrbStack
  and `exxo-1p-cache`, raises `policy:deps:cache:*`, and holds launches
  (`deps_down`) while a failed auto-start item stands. Do not start the
  cache by hand: read the item.
- **Milestones.** Every milestone land raises
  `policy:land:<task>:milestone:<id>`; the trunk service never merges one.
  Tim merges it unless the item says otherwise.
- **Releases.** On a `release_kind = tag` repo the orchestrator merges,
  verifies staging, cuts the annotated `v<date>-<n>` tag and verifies
  production before the task is `done`. Never tag by hand while a land is
  `landing`; a hold raises `policy:release:<land>` with the choices.
- **Gaps and descopes.** The heal guard (`[policy.heal]`) raises
  `policy:heal:<task>:<ref>` or creates the prerequisite task. A
  deliverable is parked only by `scope_directive` with `park: [name]` (or
  the ruling `park <deliverable>` on the heal item); wording never parks.
- **Close-out.** A task's items close at `task.done`; a decision for a gone
  member is dropped with a note; a batch closes itself.
