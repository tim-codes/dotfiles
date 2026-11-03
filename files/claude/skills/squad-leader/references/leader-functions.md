# Leader functions L1–L13 and what retires each

Taxonomy from the 2026-10-31 debug review §3 (tim-codes/squad,
`docs/superpowers/plans/2026-10-31-squad-v05-debug-review.md`), pinned in
the orchestrator's `leader.intervention` contract. Log every instance with
`intervene` (or the file log) using the function id. Counts in brackets are
the 2026-10-31 baseline the next rounds are measured against.

| # | Function | What the leader does by hand today | Retired by | Log as |
|---|---|---|---|---|
| L1 | Unblock classifier and permission refusals [about 18] | Hands the refused action to Tim with the exact command; files the squad issue that removes the need. Not logged as its own row: a refusal is logged under the function it blocked (L2, L3, L9, …) with `outcome: handed_to_tim`, and L1 is the count of those rows | #287 (trunk service owns merges and issue close-out), #288 (host-job for sandbox-blocked commands); items carry an exact one-line command | the blocked function, `outcome: handed_to_tim`, `command` |
| L2 | Merges outside the trunk service [27] | Queues framework, release and (outside the floor) milestone PRs with `trunk.land` so the service reviews and merges them; `tasks.markLanded {milestone: true}` after a milestone merges. No leader `gh pr merge`; floor-repo merges onto `main` (h2gc-portal, h2gc-legacy) wait for Tim. The nested merge-runner (ruling 38) is retired | #287; milestones not yet a member land kind the service merges | `pr`, `reason` citing `managed_repos` / `merge_scope` |
| L3 | Run sandbox-blocked work unsandboxed [75 renders, 13 items] | Runs an allow-listed render or repo gate script (`verify.sh`, `format.sh`, `node --check`) outside the member sandbox and returns the result to the member by `inbox.send` | #288 (broker host-job with a fixed allowlist); Node 24 pinned for members | `member`, `task_id`, `command` |
| L4 | Decide items [59] | `items.decide` under a ruling it can cite | #290 (rulings in the DB, routine kinds auto-decided) | `item_id`, `reason: ruling <id>` |
| L5 | Brief members [61 notes] | `inbox.send` a note: a fix landed, a new ruling, a protocol change; a nudge only in answer to a `stuck-<m>` item or a c3 watch push | #290 (ruling broadcast); idle nudges retired by supervision (v0.5.14, ENG-505), review follow-ups and verify fixes reach members by themselves (v0.5.15) | `member`, `task_id`, `item_id` |
| L6 | Session control | `sessions.resume` after a restart or a refused land; `sessions.close` an orphan (c5); a member pause or resume, an account switch (quota levers, procedures.md) | #291 (resume lost and refused-land sessions after restart), #285; the hygiene pass (v0.5.15) ends lost sessions | `member`, `session_id` |
| L7 | Rebuild and restart [10 orchestrator, 2 broker] | `deploy/ops.Justfile restart-orchestrator` (fallback: procedures.md) | #291 (verified release and restart job); #292 keeps only the attended broker re-grant | `reason`, `command` |
| L8 | Cut squad releases and tags [6] | Release PR queued with `trunk.land {kind: "release"}` onto squad `main` (`direct`, `ci: none`), tag; one re-run of a failed staging or kit (harness-kit `publish.yml`) run. Product and kit releases on `release_kind = tag` repos are the orchestrator's (v0.5.14 ENG-522, semver v0.5.15) | #293 (release task kind) | `pr`, `command` |
| L9 | File and close issues [11 filed, 20 closes] | `gh issue create/close -R tim-codes/squad`; refused closes go to Tim | #287 (closes `Closes #n` at land); members raise bugs as items the orchestrator files | `command` |
| L10 | Hygiene [35 worktrees, 20 windows] | `worktree-closedown` skill; tmux windows by name or `@id` | #239 (teardown at land; partial) plus transcript relocation in the trunk service | `task_id` |
| L11 | Plan and approve rounds [7 approvals, 3 planner lanes] | Launches a planner lane over open issues; `tasks.approve` under ruling 29 | #294 (when-idle planning under standing rulings); agentic plan review already live | `task_id`, `reason: ruling 29` |
| L12 | Operator-only legs [15 decks, 15 Slack sends] | Figma, Boards, Slack, Notion, Linear legs members cannot reach | #295 (Figma and Boards via `needs`/`provides`; concierge sends status and pairing links) | `task_id`, `item_id` |
| L13 | Watch for trouble [1,137 monitor events] | Acts on `[squad-watch] cN` pushes (procedures.md, Watching); no polling | supervision, deps watcher, doctor rows (v0.5.14); the leader watch (v0.5.15, ENG-534); #286, ENG-513 (orchestrator alerting) | one row per push acted on (`reason: c<N>`), never per push read |

Look a title up with `gh issue view <n> -R tim-codes/squad`. When an issue
closes, the function is retired only once a round's `interventions.csv`
shows zero for it; until then it stays in the table with the new count.

Every function above is now done under Tim's broad authority (SKILL.md,
Authority): the floor there bounds them, and each instance is still logged.

## What the orchestrator does on its own (v0.5.15): not the leader's job

Each of these was a hand-done intervention in an earlier round. Doing it by
hand now duplicates the orchestrator and hides whether it worked.

- **Idle members.** Supervision (`[policy.supervision]`) nudges a member
  idle 10 min with nothing to wake it, nudges again after 10 more, then
  raises `stuck-<member>` (`blocking: now`); a silent `running` session with
  a heavy grant or a Bash call in flight is escalated, never interrupted.
  Do not hand-nudge. Act only on a `stuck-<m>` item, after reading the
  activity line and the mirror log.
- **Blocked members.** A member going `blocked` promotes its own items to
  `blocking: now` or raises `blocked-<member>` (closed when it leaves
  `blocked`). Do not rank or re-flag items.
- **The secret cache.** The deps watcher (`[policy.deps]`) starts OrbStack
  and `exxo-1p-cache`, raises `policy:deps:cache:*`, and holds launches
  (`deps_down`) while a failed auto-start item stands. Do not start the
  cache by hand: read the item. It starts an empty cache; it does not warm
  it (re-warm: procedures.md, Item handling).
- **Milestones.** Every milestone land raises
  `policy:land:<task>:milestone:<id>`; the trunk service never merges one by
  itself (queue it, SKILL.md, Authority; floor repos onto `main`: Tim).
- **Review gates.** Plan review can answer `revise` (back to the planner, at
  most `max_plan_revisions`, then `policy:plan:<task>`); land review judges
  each deliverable `met | not_met | not_judged`, scales its model by diff
  risk and runs a second pass on high risk; non-blocking findings become
  `review_followups`, told to the member once per land and rolled up at
  close-out into `policy:review:<task>`. Expected checks (`ci: expected`)
  gate the merge; the approval scope parks floor-repo lands onto `main`.
- **Staging.** The orchestrator dispatches each repo's staging deploy
  (`stagingDispatch`, debounced) after lands, watches it, then launches a
  read-only verifier whose fixes go back to the live member or become one
  fix task, and whose improvements land in `verification_backlog`
  ("Backlog candidates" in the morning report). Members never run
  `gh workflow run`.
- **Releases.** On a `release_kind = tag` repo the orchestrator merges,
  verifies staging, cuts the tag (`v<date>-<n>` for publication sites such as
  theparentedit and therenaway; `semver` from the `release:` label for
  anything consumed by version, such as harness-kit, agent-tooling and
  mailkit) and verifies production (publish-only repos: the green
  tag run) before the task is `done`. Never tag by hand; a hold raises
  `policy:release:<land>` with the choices.
- **Hygiene.** At start-up and hourly the hygiene pass retires done members,
  closes finished tasks' items, ends lost sessions, cancels stray lands and
  lists what it is unsure of in `policy:hygiene:<run>`.
- **Denials and queues.** A classifier denial in any squad session raises
  `policy:denied:<task>`; a land queued past `queued_timeout_s` raises
  `policy:land:<task>:queued`; reviewers and releasers are supervised like
  members.
- **Gaps.** The heal guard (`[policy.heal]`) auto-creates a missing
  prerequisite only in a managed, not `operator_only` repo, as an
  `evaluating` task (through plan review; never from a heal-created task);
  otherwise it raises `policy:heal:<task>:<ref>` with a proposal.
- **Descopes.** Wording never parks. The leader parks with `submit_task
  {task_id, park: [exact deliverable name]}` on the running task, or the
  ruling `descope <name>` / `park <name>` on the heal item (exactly one
  name, else the item stays open listing them); `scope_directive` is the
  concierge's tool.
- **Close-out.** A task's items close at `task.done`; a decision for a gone
  member is dropped with a note; a batch closes itself.

## Quota guarding (v0.5.15, ENG-535)

What the orchestrator does alone; the leader's levers are in procedures.md,
Quota.

- **Gauges.** Each account's 5-hour and 7-day use is normalised to its
  `reserve_pct` (ceiling `100 - reserve_pct`) and read as a level: green,
  amber, red, wall, against `[policy.quota] act_pct` (70) and `pause_pct`
  (95), the wall at `wall_pct` (100); per-account overrides in
  `[[accounts]]`.
- **Placement.** Each launch goes to the greenest eligible pool
  (`resources.account`, `placement_rank`, fewest provides, lowest use) and
  skips pools that are not green; none fits: the wait `pools_busy`.
- **Ladder,** per account as it climbs: fan-out and model caps, one
  proactive switch of a member to a headroom account, heavy-grant
  revocation, pausing the hottest low-priority member, and at the wall
  evacuation (move what can move, pause the rest). Pre-emption pauses
  lower-priority work when the cap or pools are the limit. A window roll or
  a held projected recovery restores the pool and resumes members one by
  one. An account switch carries the transcript.
- **New in v0.5.15.** A session's own result naming a usage, weekly,
  session or 5-hour limit forces that account to the wall (`quota.limit_hit`)
  until a fresher sample or the reset; every account of a `resume_group`
  exhausted raises one blocking `policy:quota:exhausted:<group>`, closed by
  itself on restore; operator member pause/resume, which the ladder's
  restore leaves alone; a manual switch onto a hot account is refused
  (`target_not_green`) unless `allowHot`.
- **No squad-wide quota pause** exists, by design: the leader rebalances or
  pauses members. Known gap: disabling an account or changing its ceiling
  at runtime needs a config edit and an orchestrator restart (only to
  recover a dead one unattended, so it waits for Tim); `sessions.resume`
  cannot name an account.
