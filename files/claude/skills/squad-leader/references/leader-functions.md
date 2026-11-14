# Leader functions L1–L13 and what retires each

Taxonomy from the 2026-10-31 debug review §3 (Exxo-Labs/gaia,
`docs/superpowers/plans/2026-10-31-squad-v05-debug-review.md`), pinned in
the orchestrator's `leader.intervention` contract. Log every instance with
`intervene` (or the file log) using the function id, and pass `desk_class`
(SKILL.md, Interventions) with it. Counts in brackets are
the 2026-10-31 baseline the next rounds are measured against.

| # | Function | What the leader does by hand today | Retired by | Log as |
|---|---|---|---|---|
| L1 | Unblock classifier and permission refusals [about 18] | Hands the refused action to Tim with the exact command; files the squad issue that removes the need. Not logged as its own row: a refusal is logged under the function it blocked (L2, L3, L9, …) with `outcome: handed_to_tim`, and L1 is the count of those rows | #287 (trunk service owns merges and issue close-out), ENG-484 (broker host job for sandbox-blocked commands, R7); items carry an exact one-line command | the blocked function, `outcome: handed_to_tim`, `command` |
| L2 | Merges outside the trunk service [27] | Queues framework and release PRs with `trunk.land` so the service reviews and merges them. Milestones are the trunk service's from 0.6.0, and a docs-only or path-filtered PR merges on review alone (R3). No leader `gh pr merge`; floor-repo merges onto `main` (h2gc-portal, h2gc-legacy) wait for Tim. The nested merge-runner (ruling 38) is retired | #287; the trunk service lands milestones and path-filtered PRs (v0.6.0 R3) | `pr`, `reason` citing `managed_repos` / `merge_scope` |
| L3 | Run sandbox-blocked work unsandboxed [75 renders, 13 items] | Runs an allow-listed render or repo gate script (`verify.sh`, `format.sh`, `node --check`) outside the member sandbox and returns the result to the member by `inbox.send` | ENG-484 (broker host job with a fixed allowlist, R7); Node 24 pinned for members | `member`, `task_id`, `command` |
| L4 | Decide items [59] | `items.decide` under a ruling it can cite | ENG-476 (standing rulings in the database, routine kinds auto-decided, R2) | `item_id`, `reason: ruling <id>` |
| L5 | Brief members [61 notes] | `inbox.send` a note: a fix landed, a new ruling, a protocol change; a nudge only in answer to a `stuck-<m>` item or a c3 watch push | ENG-476 (decision and ruling broadcast to the member, R1, R2); idle nudges retired by supervision (v0.5.14, ENG-505), review follow-ups and verify fixes reach members by themselves (v0.5.15) | `member`, `task_id`, `item_id` |
| L6 | Session control | `sessions.resume` after a restart or a refused land; `sessions.close` an orphan (c5); a member pause or resume, an account switch (quota levers, procedures.md) | ENG-475 (resume lost and refused-land sessions after restart), #285; the hygiene pass (v0.5.15) ends lost sessions | `member`, `session_id` |
| L7 | Rebuild and restart [10 orchestrator, 2 broker] | `deploy/ops.Justfile restart-orchestrator` (fallback: procedures.md) | ENG-475, ENG-477 (verified release and restart job, R5); #292 keeps only the attended broker re-grant | `reason`, `command` |
| L8 | Cut squad releases and tags [6] | Release PR queued with `trunk.land {kind: "release"}` onto squad `main` (`direct`, `ci: none`), tag; one re-run of a failed staging or kit (harness-kit `publish.yml`) run. Product and kit releases on `release_kind = tag` repos are the orchestrator's (v0.5.14 ENG-522, semver v0.5.15) | #293 (release task kind) | `pr`, `command` |
| L9 | File and close issues [11 filed, 20 closes] | `gh issue create/close -R Exxo-Labs/gaia`; refused closes go to Tim | #287 (closes `Closes #n` at land); members raise bugs as items the orchestrator files | `command` |
| L10 | Hygiene [35 worktrees, 20 windows] | `worktree-closedown` skill; tmux windows by name or `@id` | #239 (teardown at land; partial) plus transcript relocation in the trunk service | `task_id` |
| L11 | Plan and approve rounds [7 approvals, 3 planner lanes] | Launches a planner lane over open issues; `tasks.approve` under ruling 29 | ENG-485 (when-idle planning under standing rulings, R8); agentic plan review already live | `task_id`, `reason: ruling 29` |
| L12 | Operator-only legs [15 decks, 15 Slack sends] | Figma, Boards, Slack, Notion, Linear legs members cannot reach | ENG-486 (operator-only surfaces as member-reachable reads or `needs`/`provides`, R9; concierge sends status and pairing links). Data legs retire to `data_read` and the `data_access:` item: the leader never runs a data query for a member (Tim decides the item, or runs `data.readFor`). Sign-in legs retire to the tracker, the preflight auth pass (`pf-auth:` steps in the pre-launch checklist) and `auth_login`; a sign-in nothing saw is recorded with `record_auth_event` (operator session) or `authEvents.record`, so the next preflight prepares it | `task_id`, `item_id` |
| L13 | Watch for trouble [1,137 monitor events] | Acts on `[squad-watch] cN` pushes (procedures.md, Watching); no polling | supervision, deps watcher, doctor rows (v0.5.14); the leader watch (v0.5.15, ENG-534); #286, ENG-513 (orchestrator alerting) | one row per push acted on (`reason: c<N>`), never per push read |

The GitHub issues #288, #290, #291, #294 and #295 were closed in the 2 Nov
sweep without being built; they reappeared in Linear as the ENG-n above,
and v0.6.0 builds them: plan
`docs/superpowers/plans/2026-11-04-squad-v0.6.0-retirement-plan.md`, spec
`2026-11-04-squad-v0.6.0-retirement-spec.md` (squad repo; R1 to R13 there).
Look a Linear issue up through the Linear MCP; the other `#n` are GitHub
issues (`gh issue view <n> -R Exxo-Labs/gaia`). When an issue ships, the
function is retired only once a round's `interventions.csv` shows zero for
it; until then it stays in the table with the new count. A round is
unattended when L1 to L12 total zero interventions.

Every function above is now done under Tim's broad authority (SKILL.md,
Authority): the floor there bounds them, and each instance is still logged.

## What the orchestrator does on its own (v0.5.15, v0.6.0): not the leader's job

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
- **Milestones.** From 0.6.0 the trunk service lands a milestone itself
  (`[policy.trunk] milestone_lands = 'service'`, the default); only a floor-repo milestone
  onto `main` waits for Tim. Never merge one by hand.
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

### New in v0.6.0 (retirement plan R1 to R11)

Check the event or item named here, not the member's inbox; do not repeat
the action by hand.

- **Decision notes (R1).** `items.decide`, and every auto-decide path below,
  writes the decision and its reason to the inbox of the member that raised
  the item, in one tick. Do not send a "your raise is decided" note (L5).
- **Standing rulings (R2).** An `items.raise` whose kind matches an active
  ruling is decided at once with `reason: ruling <id>` (event
  `item.auto_decided`); routine kinds are seeded. Add a ruling through
  `rulings.put` or the concierge `add_ruling`; it is broadcast to live
  members once. Cite the id; do not decide the same kind by hand (L4).
- **Docs-only and path-filtered PRs (R3).** A land whose changed files all
  match `ci_paths_ignored` (or the workflow's `paths-ignore`) merges on
  review alone and records `checks: skipped_by_paths`. No hand merge.
- **GitHub incidents (R4).** The deps watcher's `forge` dependency holds
  pushes and lands that fail with the incident's signature `retry_later`
  with a backoff and no item, and tells members once. Do not decide or
  resume around it; the hold lifts when the probe is green.
- **Release and restart (R5).** A squad release land restarts the
  orchestrator itself (pull, migrate, build, launchd restart, health check,
  session resume) and rolls back to the previous build on a failed check;
  `restart-orchestrator` calls the same code. A failed staging deploy or kit
  publish run is rerun once by the service before it raises an item. The
  leader checks the health result and any `policy:self-release:<id>` item (procedures.md, Item handling), and does not run
  `gh run rerun` first (L7, L8).
- **Refusal classes (R6).** Refusals are classed A to I; class C is the
  reviewer's `just ci` in a scratch worktree, answered by the `review-ci`
  recipe grant, and a known-safe `policy:denied:<task>` kind is ruled by R2.
  A class that still needs Tim carries the exact command in its item (L1).
- **Host jobs (R7).** The broker runs allow-listed jobs (`verify.sh`,
  `format.sh`, `node --check`, repo render scripts in
  `managed_repos.host_jobs`) outside the member sandbox on the member's
  `mcp__squad__host_job` request, with the result returned to the member;
  every run is a `broker.host_job` event. Do not run a render for a member
  (L3). Needs the attended broker rebuild.
- **When-idle planning (R8).** With capacity and an empty batch queue the
  orchestrator launches one backlog planner over Linear and GitHub issues
  under the standing rulings and the planning rule; the batch waits for
  approval (`policy:backlog:<batch_id>`, procedures.md) unless a ruling on
  `policy:backlog:*` approves it. Off by default
  (`[policy.backlog] enabled`) until the planner skill with the `--backlog`
  form is installed. Do not launch a planner lane by hand (L11).
- **Member-reachable surfaces (R9).** Read-only surfaces members could not
  reach have a read path; a human or helper step is declared as a `needs`
  in the plan, so it arrives as a planned item, not a surprise. Usage rows
  in a client project's ClickHouse are a `needs` a human supplies. Deliver
  only what a `needs` item asks of you (L12).
- **Verifier (R10).** The staging verifier runs in a prepared worktree (env
  copied in, `just` on PATH) with a heavy slot, reads staging data and runs
  the live flows a `stage: staging` deliverable names.
- **Session hygiene (R11).** The leader watch pushes a `blocking: later`
  item once per instance (c8), then only on change; background shell jobs a
  member starts are on its roster row and in the mirror; headless mirror
  windows are closed when their session ends. Close a window by hand only on
  a c5 or c12 push.

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
