# Leader procedures

Everything here is the fallback for something the squad should do itself.
Each use is an intervention (L-function in brackets). Written for squad
v0.5.15: the orchestrator on it, the broker on it after Tim's attended
rebuild (`squad --version`, the `squad doctor` version row; until then the
releaser and verifier fall back, row 3).

## Pre-flight before an unattended round

Run it with Tim present; write the result to `preflight-<run>.md` in your
scratchpad (one line per row: `ok`, or what is wrong and the fix) and copy
it into the consolidated ask and the round summary. A row you could not
check is not `ok`.

1. **Logins and cache warmth.** `/reauth` (`scripts/claude-reauth`):
   every row `ok`. `agent-tooling cache status` shows `1Password items` > 0
   and a Pulumi token present: doctor's `cache` row is `ok` for a reachable
   but empty cache, and the orchestrator can start an empty cache but does
   not warm it.
2. **Doctor.** `squad doctor`: `cache`, `version` (broker and binary both
   match the orchestrator) and `orchestrator` (connected, no outage
   duration) `ok`; no `login gh|gcloud|pulumi` row `warn` (they are
   `info`/`warn` only). The dashboard's dependency strip is green and no
   `policy:deps:*` item is open.
3. **Build.** `squad --version` is the build that was tested; the
   orchestrator released on v0.5.15 (migrations 0098–0102 applied). After
   any rebuild, App Management and Full Disk Access were re-toggled
   (Attended rebuild, below). A `release.verify_fallback` or
   `verify.fallback` event (or the info item `policy:release:<land>:verify`)
   means the broker rebuild is still pending: the releaser's checks and the
   staging verifier do nothing until it is done. Name it in the ask.
4. **Sessions.** `squad sessions`: no stale alive session (a planner of a
   rejected task, an exited member's mirror). The hygiene pass ran (the
   Overview's Processes card); act on what its `policy:hygiene:<run>` item
   lists as unsure.
5. **Pause.** BFF `squad.state` is `{paused: null}`, or paused
   deliberately with a note Tim gave; never paused by accident.
6. **Repos.** BFF `repos.list` shows the batch's repos registered as the
   v0.5.15 Rollout gives them (task 38's `blocks_launch` step). The calls,
   with the leader cookie (tRPC access, below; omit `checkoutPath`, which
   `repos.put` keeps):

   ```bash
   t() { curl -fsS -b "$JAR" -H 'content-type: application/json' -d "$2" "http://127.0.0.1:7790/trpc/$1"; }
   t repos.put '{"repo":"Exxo-Labs/h2gc-portal","trunkPolicy":"trunk","approvalScope":"default_branch","stagingUrl":"https://portal.staging.h2gc.exxo.dev","verifyRecipe":"just e2e","stagingDispatch":{"workflow":"ci.yml","inputs":{"deploy_staging":"true"}},"ci":"expected","expectedChecks":["Lint & Typecheck","Unit Tests","Build Backend","Build Portal (platform)","Build Portal (standalone)","Basic Integration Tests","Database Integration Tests","PyOdide Tests","OpenAPI Spec"]}'
   t trunk.register '{"repo":"Exxo-Labs/h2gc-portal","branch":"release/ario-v0.4","base":"main"}'
   t repos.put '{"repo":"Exxo-Labs/harness-kit","trunkPolicy":"direct","releaseNeedsApproval":false,"releaseKind":"tag","releaseTagPattern":"semver","releaseWorkflow":"publish.yml","ci":"expected","expectedChecks":["ci"]}'
   t repos.put '{"repo":"Exxo-Labs/h2gc-legacy","operatorOnly":true}'
   t repos.put '{"repo":"Exxo-Labs/gaia","ci":"none"}'
   t repos.put '{"repo":"Exxo-Labs/theparentedit","verifyRecipe":"just watch-rollout $GAIA_RUN_ID"}'
   ```

   Re-derive `expectedChecks` from a recent PR whenever a workflow changes:
   `gh pr checks <pr> -R <repo> --json name,workflow` (portal: the `CI`
   workflow's PR jobs; harness-kit: `ci`, since `publish.yml` runs on tags).
   The portal's CI is path-filtered. From 0.6.0 a land whose changed files
   all match `ci_paths_ignored` (or the workflow's `paths-ignore`) merges on
   review alone and records `checks: skipped_by_paths` (R3); set
   `ci_paths_ignored` on the repo row rather than registering `ci:
   "unknown"`. Squad and theparentedit stay `direct`; exxo-infra stays
   unregistered. Registering repos is within the leader's authority [L4].
7. **Plans.** Every task of the batch `approved`, its plan with structured
   `prerequisites` (no dependency in prose only), a `stage` on each
   deliverable, typed checks where they can be run, and a release
   convention for any `production` stage. The four "Cut and publish the
   harness-kit release" fallback `blocks_step` items (tasks 38, 39, 40, 41)
   stay open until the squad has cut the kit tag itself; then the leader
   drops each with `items.decide` naming the tag and run [L12].
8. **Capture.** `squad debug on --run <run>`, then BFF `runs.current` shows the
   run with `mode: debug` (Capture readiness, below).
9. **Leader watch.** `just -f /Users/tim/dev/squad/deploy/ops.Justfile
   leader-watch-dry-run` (what it would push now), then `leader-watch-start
   main:<leader window>` (or `uds:$CLAUDE_CODE_MESSAGING_SOCKET`);
   `leader-watch-status` shows the job running with your target. Restart it
   with the new target whenever the leader session changes.
10. **Presence and the ask.** `presence.set {attending: false}` as Tim
    leaves; the consolidated ask sent and answered.

## Watching: the leader-watch pushes [L13]

`dev.tim.squad-leader-watch` reads the squad every 120 s, never acts, and
keeps working while the orchestrator is down. A push reads `[squad-watch]
c<N> <title> | evidence: … | suggested: …`; one per condition instance per
30 min unless it worsens. Each push is a prompt to look, not proof: read the
evidence against the live state, take the first action below, and log it
with `reason: c<N> …`. A push that needs nothing gets no turn of tool calls
beyond that check. Between pushes, read the roster activity line and the
todo card only when you act anyway.

| Push | First action |
|---|---|
| c1 orchestrator unreachable | `squad doctor`, `launchctl print gui/501/dev.tim.squad-orchestrator`; `restart-orchestrator --dry-run`, then for real only if it is dead, sessions counted, no tag release mid-flight [L7] |
| c2 broker down | Doctor and `launchctl print gui/501/dev.tim.squad-broker`; `restart-broker` (refuses while a session is mid-turn) [L7]; never bootout or `cargo install` by hand |
| c3 idle member, no `stuck-` item | Activity line and mirror log; one `inbox.send` naming the next step, or `sessions.resume` [L5]; check `[policy.supervision] enabled` |
| c4 member with no live session | `squad sessions` and the mirror log for why; `sessions.resume` [L6] |
| c5 orphan planner or reviewer | `sessions.close` it [L6] |
| c6 session running without events | Mirror log; wedged: one `inbox.send`, then `sessions.resume` (a planner or reviewer: close it) [L6]; never interrupt a heavy grant or mid-Bash |
| c7 land stuck in a stage | BFF `trunk.lands {repo}` and the land's item; act by the item table (a queued land: its wait reason) |
| c8 release failed or release item | The `policy:release` / `policy:staging` rows below [L8] |
| c9 cache down or empty | Doctor and `agent-tooling cache status`; leave `deps_down` standing; re-warm first on Tim's list |
| c10 squad paused | Nobody meant it: `squad-resume <note>` [L6]; a pause Tim set stays, named in the hand-back |
| c11 `blocking: now` undecided | `items.decide` under a cited ruling and tell the member [L4]; else park with the proposal |
| c12 done member unretired | The hygiene item says why; retire it, close its mirror, `worktree-closedown` [L10] |
| c13 ceiling here, headroom there | Quota, below: let the rebalance run, else `policy.switch.request` the busiest member [L6] |
| c14 member stuck on a quota error | `policy.switch.request` to a green account, or `sessions.resume` after the reset [L6] |
| c15 quota hold with capacity | Resume a quota-only pause (member or squad); else move held members to the headroom account [L6] |

## Item handling on an unattended night

Where to look first: the roster activity line ("is work happening?"; the
GUI member card, BFF `roster.list`), then the todo card (ask the concierge;
`show_todo` is its tool: `Todo: N new, M can wait, K blocking`), then the
`blocking: now` items. "Alone" means under Tim's standing rules or a
ruling you cite; "park" means a line on Tim's list with the ready
proposal and exact command, the item left open. Log every action.

| Item | The leader decides alone | Parks for Tim | Never unattended |
|---|---|---|---|
| `stuck-<m>`, `blocked-<m>` | One concrete action (below) [L5, L6] | A wait only Tim can end (sign-in, grant, a decision no ruling covers) | Interrupt a session holding a heavy grant or mid-Bash; loosen a threshold |
| `policy:heal:<task>:<ref>` | Approve a heal-created task once its plan review passed (ruling 29) [L11] | The create-or-descope choice, with the item's proposal | Descope by wording or by editing the plan |
| `policy:plan:<task>` | Approve under ruling 29 when the notes are nits [L11] | The plan, the review's notes and a proposal | Approve over a conformity objection |
| `policy:deps:cache:*` (blocking now) | Check `squad doctor` and `agent-tooling cache status`; leave the hold (`deps_down`) standing | The item's commands and the re-warm (below) | Lift `hold_launches`; `docker rm` the cache; ad hoc `op` |
| other `policy:deps:*` | Tunnel kickstart (Tunnel check) [L7]; a `login` warn onto the morning list | A broker link down for three ticks, with `launchctl print` output | Restart the broker with sessions mid-turn |
| `policy:deps:broker_version:*` | Record which side is old | The attended rebuild, first on the morning list | `cargo install` or `restart-broker` unattended |
| `policy:staging:<repo>:<ms>` (blocking later) | The service already reran the failed run once (R5 `rerun_failed_once`) before this item, so a `gh run rerun <id> -R <repo> --failed` is the second attempt; or `trunk.deployStaging {repo}` once the cause is fixed [L8] | A second red run, with `gh run view` | `gh workflow run` by hand or by a member |
| `policy:release:<land>` (blocking now) | Staging stage, or a harness-kit publish run: the service already reran it once (R5 `rerun_failed_once`), so one `gh run rerun <run> -R <repo> --failed` is the second attempt [L8] | A production failure, re-run and rollback commands ready; a BREAKING bump hold | Roll back, retag, delete a tag, set `release_kind` to `none` |
| `policy:release:<land>` (blocking later) | Nothing: `release_ready` is the approval repo's stop | The exact command | Run it |
| `policy:release:<land>:verify` (info) | Note the broker rebuild is pending | The rebuild | — |
| `policy:verify:<task>` | Read the finding; approve its fix task through plan review (ruling 29) [L11] | A fix that failed twice | Edit the deliverable to pass |
| `policy:review:<task>` (blocking later) | `tasks.setFollowup {id, status, note}` where the record shows it; a real gap becomes a fix task or a Linear issue [L4] | Follow-ups needing Tim's judgment | Mark `done` what was not done |
| `policy:land:<task>` | Pass a fixable refusal on | Third refusal, review timeout, `operator_only`; a floor-repo land onto `main` ("until Tim returns") | Merge onto h2gc `main`; re-aim a PR to dodge the floor; delete a branch; force-push |
| `policy:land:<task>:queued` | Read the wait reason; `no pool`: rebalance (Quota) [L6] | — | — |
| `policy:land:<task>:milestone:<id>` | Nothing from 0.6.0: the trunk service lands it (`[policy.trunk] milestone_lands = 'service'`, the default); confirm the land recorded | A floor-repo milestone onto `main` | `gh pr merge` it yourself |
| `policy:backlog:<batch_id>` (approval) | Options approve or deny. An operator ruling on `policy:backlog:*` approves it. Approve acts only on plans that passed plan review (`plan_review.approve` held for the backlog); unreviewed ones wait for their verdict [L11] | Whether the backlog is worth running when no ruling covers it | Approve a plan that has not passed plan review; launch a planner lane by hand. Deny rejects the tasks and closes the batch |
| `policy:self-release:<id>` (blocking now) | Raised when a self-release's build, kickstart, health check or rollback fails. Read the log path in the item text, then run the recipe it names: `just -f deploy/ops.Justfile restart-orchestrator`, or `release-orchestrator --rollback` after a failed rollback kickstart, or `launchctl bootstrap gui/<uid> ~/Library/LaunchAgents/dev.tim.squad-release.plist` when the job is not loaded [L7] | A rollback that also fails | Bootout on a build whose log says `recipe failed` |
| `policy:denied:<task>` | Read it; the member works on [L1] | The denied write as the exact command | Retry it in another form |
| `policy:quota:exhausted:<group>` (blocking now) | Nothing moves: confirm with BFF `policy.pools`; the squad waits for the reset | Note the reset time on the morning list | Spend past a ceiling; `allowHot` onto the wall |
| `policy:hygiene:<run>` (info) | Retire or close what it lists once checked [L10] | Anything of Tim's (his sessions, worktrees) | Remove a worktree without `worktree-closedown` |
| `pf-*` (preflight steps) | Deliver a step you can (deck, Boards publish, kit fallback once the tag exists) and `items.decide` with the result [L12] | Sign-ins, grants, anything needing Tim's hands | Grant TCC or a permission yourself |
| `r-*` (member raises) | `items.decide` under a cited ruling (round rulings below); the member acks [L4] | Anything needing Tim's judgment, with a proposal | Decide outside the rulings; re-ask a denied write in another form |

- **`stuck-`/`blocked-`.** Read the activity line and the member's mirror
  log first; then one concrete `inbox.send` naming the next step,
  `sessions.resume` an exited session, or decide the item the member waits
  on. `stuck-<m>` closes on progress; `blocked-<m>` when the member leaves
  `blocked`.
- **Cache outage.** After any outage or auto-start the cache is empty, even
  when the `info` item closed at once as `restarted by the squad`. Re-warm
  with `/reauth` (Tim at the keyboard); otherwise put it first on the
  morning list and expect lanes to hang on 1Password. Known gap: land-refusal
  and account-switch resumes are not held by `deps_down` (ENG-507).
- **Release and staging re-runs.** From 0.6.0 the service reruns a failed
  staging deploy or kit publish run once (`--failed`) before it raises an
  item (R5). A `policy:staging:*` red run, or a failed harness-kit
  `publish.yml` tag run, that still stands is a second red: one `gh run
  rerun <run> -R <repo> --failed` and look at `gh run view`. A product
  production failure goes to Tim.
- **Land refusals.** A fixable refusal goes to the member (review
  follow-ups and verify fixes reach it by themselves); `tasks.markLanded`
  only after a merge was made.
- **Docs-only portal land.** From 0.6.0 the orchestrator merges it on
  review alone (`checks: skipped_by_paths`, R3). The leader checks that the
  land recorded that and that `ci_paths_ignored` covers the repo's filter;
  a docs-only land still reaching the operator with `expected checks never
  registered` means the filter is missing from the repo row: fix the row,
  do not hand merge.
- **Descope** (with Tim's ruling): `submit_task {task_id, park: [exact
  deliverable name]}` on the running task, or the ruling `descope <name>` /
  `park <name>` on the heal item, which parks only when it names exactly one
  deliverable (otherwise the item stays open and lists the names).
  `scope_directive` is the concierge's tool.
- **Orchestrator recipes.** `release-orchestrator` only on Tim's go.
  `restart-orchestrator` only to recover a dead orchestrator (doctor
  `orchestrator` row failing), after counting sessions, and never while a
  `tag` repo's task is `landing` mid-release. Otherwise only the
  `--dry-run`s (the ops.Justfile header: agents run only the dry run).

Anything a classifier or permission check denied is never retried
unattended in any form: it goes on Tim's list as the exact command.

## Round rulings

Cite these by name when a member raises the case; do not escalate it.

- **Ario v0.4 staging purge (Tim, 2026-11-03).** A v0.4 schema change to
  the Mongo Ario state may purge the affected **staging** collections
  instead of migrating them: authorised without further notice to H2, who
  are already warned. Before any purge the member dumps exactly those
  collections to
  `~/.local/state/squad/backups/mongo/<repo>/<YYYY-MM-DD>-<task_id>/`,
  the connection string resolved by `agent/run` and never printed (e.g.
  `agent/run -- sh -c 'mongodump --uri "$<staging URI var>" --db <db>
  --collection <c> --out <dir>'`, once per collection), records the path
  and the collection list in the task's land record and the PR body, then
  purges. Staging only; production is never touched. A purge without the
  dump, or of anything else, is outside the ruling: park it.

## Releasing the round's trunk (v0.6.0 R17)

1. `trunk.release {repo}` (tRPC, the leader's cookie). It answers `{releaseId, state: planning}`; the
   service plans, builds, checks, pushes `release/<name>` over SSH and opens the release PR. Refusals:
   NOT_FOUND (no open trunk), PRECONDITION_FAILED (compaction off, chunk merges, repo settings, the
   name taken: pass `name`), CONFLICT (a release is already live).
2. Skim the group table on the item `policy:trunk-release:<id>` (and `trunk.releasePlan {releaseId}`).
   No code review: the nine checks prove the content is the trunk's.
3. Choose `merge:<tip10>` on that item once you are content. The service merges when the release
   PR's checks are green, through the trunk service (one merge commit). If the trunk moved, the
   release re-cuts and the item comes back without its decision: choose again for the new tip.
   `hold` waits; `abandon` closes the PR and deletes the branch (or `trunk.abandonRelease {releaseId}`).
4. `publish_failed`: follow the item's `squad-compact` path (the trunk-compaction skill) by hand.
   `sync-by-hand`: main does not merge into the trunk cleanly — merge it into the trunk by hand; the
   release re-cuts.
5. A trunk that reached main through checkpoint merges is refused (B8): finish it the old way with
   `trunk.land {kind: checkpoint}`; its successor is released by compaction.

In a floor repo (h2gc-portal) the choice of `merge:<tip10>` stays Tim's.

## Trunk CI (R20)

`trunk.ciDispatch {repo}` runs the repo's full CI against its trunk on demand; the squad also runs it every 10 lands or 6 hours. A red run is the item `policy:trunk-ci:<repo>` and marks the trunk `ci_red`: lands continue, but open a fix lane before the release cut. The release PR's CI is mandatory and is checked by GitHub. `buildlab` has a gauge and a `squad doctor` row. When it is unreachable, lands queue and `policy:verify-run:<repo>` names the cause (auth, key file, plugin path); fix it and the lands resume.

## Landing a testable version by morning

The goal of an overnight batch: every task ends in one of three states.

- `done`: released to production on a `tag` repo (the concierge's
  "released to production" notice names tag and run), merged on the
  others; a `tag` repo needing approval also finishes `done`, with a
  `blocking: later` `release_ready` item on the land row naming the command.
- `landing`, with an open item for Tim naming the exact command (a merge
  Tim makes, a held release); a floor-repo milestone onto `main` waits on
  its merge item while the task runs on.
- Parked: a clear note on the task (what is parked, why, what unblocks it).

Nothing ends silently `running` or `blocked`. **Morning hand-back**, one
message, built from the morning report (`squad://morning`, BFF
`reports.morning`, or the concierge's `show_morning`), in this order:

1. Landed: per repo, task, PR, merge sha, and the tag plus run link (tag
   repos, semver for harness-kit), the trunk merge (Ario) or the merge
   (others); staging deploys and their verification results.
2. Held: each item, why, and the exact command Tim runs; first the
   floor-repo lands parked "until Tim returns" and the Ario checkpoint.
3. Parked: deliverables and tasks, with the ruling or note; open review
   follow-ups; "Backlog candidates", each filed in Linear (issue id).
4. Stalls and escalations: each `stuck-`/`blocked-` item, how long, how it
   cleared (supervision alone, or a leader action with its L-function).
5. Dependency incidents: each `policy:deps:*` item, the outage length,
   auto-start or not; the cache's `1Password items` count now and any
   re-warm done.
6. Open `blocking: now` items by id, and the asks that were unforeseeable.
7. Interventions L1–L13 with counts, every action taken under the broad
   authority with its one-line reason (staging purges with their dump
   paths), and the `squad debug` bundle name (`debug/<run>/bundle/`) for
   the `squad-debug-review` lane.
8. State as left: paused or not (and why); `squad --version` and doctor's
   `version` row.

## Quota: the leader's levers [L6]

The orchestrator guards quota alone (leader-functions.md, Quota guarding);
act only on a c13–c15 push, a `policy:quota:exhausted:*` item or a member
stuck on a limit. tRPC with the leader cookie:

- Read (BFF): `policy.pools` (levels, normalised use, ladder rung per account;
  also the concierge's `read_state pools`) and `policy.switches`.
- Move a member: `policy.switch.request {member, toAccount}`; a target that
  is not green is refused (`target_not_green`). `allowHot` only to rescue a
  member stuck on an exhausted account onto one with real headroom, never
  onto a red or wall pool.
- Pause or resume one member: `policy.members.pause {member, reason}` /
  `policy.members.resume {member}`; an operator pause overrides the
  ladder's and is not restored by it, so resume it yourself.
- Stop or change automatic moves: `policy.rebalance.setMode {mode}` (`act`,
  `attended`, `advisory`, `off`; null restores the config); undo one
  pre-emption or rebalance with `policy.decisions.reverse {id}`.
- Sessions: `sessions.close` / `sessions.resume` (by session, not account);
  the squad as a whole: `squad.pause` / `squad.resume` (the ops recipes).

There is no squad-wide quota pause by design: rebalance or pause members.
Disabling an account or changing its ceiling needs a config edit and a
restart, so unattended it waits for Tim. Never spend past a ceiling.

## Pause and resume

`just -f /Users/tim/dev/squad/deploy/ops.Justfile squad-pause <note>`
holds launches and messages (live sessions finish their task);
`squad-resume <note>` lets admission run at once. At the start of an
unattended run, pre-flight row 5 must find the squad unpaused or paused on
purpose. At the end, leave it as Tim asked: a pause you set for a restart
is lifted before you hand back; a pause he wants for his review is set with
a note and named in the hand-back.

`deploy/squad-pause.sh` has no planning or building subcommands. To pause or
resume only planning or only building, use the GUI's "Planning" and "Building"
switches, or the actions `squad.pausePlanning`, `squad.resumePlanning`,
`squad.pauseBuilding` and `squad.resumeBuilding`.

## tRPC access

The orchestrator's action API listens on `http://127.0.0.1:7790`. From
0.6.0 the dashboard's read API is no longer served there: the GUI is the
BFF at `http://127.0.0.1:7780` (bookmark that one), reading Postgres
through a read-only role, and 7790 keeps only the action API.

Reads: `GET http://127.0.0.1:7780/bff/<name>`; actions: `POST
http://127.0.0.1:7790/trpc/<action>`; 7790 refuses reads. The BFF forwards
`/auth/*`, so the same cookie works on both. Sign in locally with
the leader label (the label must match `^[a-z][a-z0-9_-]{0,31}$`) so
mutations record actor `gui:leader`:

```bash
JAR=/path/in/scratchpad/leader.jar
curl -sS -c "$JAR" -o /dev/null 'http://127.0.0.1:7790/auth/local?label=leader'
```

Or pair: `POST /auth/pair` with body `{"label":"leader"}`, then redeem the
returned `url` path with `-c "$JAR"`. The minted URL is relative when
`public_url` is unset, so prefix the tunnel origin yourself. (`squad pair
--as leader` does the same from the CLI after the attended rebuild.)

Then call `/trpc/<router>.<procedure>` with `-b "$JAR"`; the POST body is
the input itself. Recording an intervention:

```bash
curl -sS -b "$JAR" -X POST http://127.0.0.1:7790/trpc/operator.intervene \
  -H 'content-type: application/json' \
  -d '{"function":"L2","action":"floor-repo merge tim-codes/squad#277 refused by the classifier; command on Tim'"'"'s list","reason":"land refused by the classifier, command on the list","outcome":"handed_to_tim","pr":"tim-codes/squad#277"}'
```

Mutations the leader uses: `tasks.approve`, `tasks.markLanded`,
`tasks.setFollowup`, `items.decide`, `inbox.send`
(`{to: {member}, priority: 'now', kind: 'note', text}`), `sessions.resume`,
`sessions.close`, `presence.set`, `repos.put`, `trunk.register`,
`trunk.land`, `trunk.deployStaging`, the quota levers above,
`operator.intervene`. Annotating a run is not a tRPC procedure: use the ops
recipes (or the loopback `POST http://127.0.0.1:7790/ops/annotate`, no cookie).
Reads go to the BFF, not `/trpc`: `runs.current`, `runs.list`, `repos.list`,
`roster.list`, `squad.state`, `trunk.lands`, `policy.pools`, `policy.switches`,
`reports.morning` (GET `http://127.0.0.1:7780/bff/<name>`).

## Capture readiness check

```bash
squad debug on --run <run>    # writes <state>/debug.on (src/cmd/debug.rs: --run is a flag)
```

Then `runs.current` from the BFF: the run id with `mode: debug` and
`started_at` is the proof. After the attended rebuild `squad debug on` also
prints `orchestrator: recording` and `squad doctor` has a debug row. If
`runs.current` shows the implicit `auto-<date>` run or nothing, the
orchestrator did not notice the switch: fix that before declaring the
round started. The broker sinks (`host.jsonl`, `quota.jsonl`) prove
nothing about the orchestrator.

## Intervention log file (orchestrator older than v0.5.10)

Only if `operator.intervene` is missing: one JSON line per action appended
to `~/.local/state/squad/debug/<run>/interventions.jsonl` with the
`leader.intervention` fields (`ts` UTC ISO-8601, `function`, `action`,
`reason`, `outcome`, `pr`, `item_id`, `task_id`, `member`, `command`,
`session_id`, `actor: "leader"`; unused ids `null`). The bundle merges it.
Never a token, cookie, password or secret value in any field.

## Restart and release the orchestrator [L7, L8]

`just -f /Users/tim/dev/squad/deploy/ops.Justfile restart-orchestrator`
(this checkout) and `release-orchestrator` (the primary checkout on `main`,
level with `origin/main`). They build on Node 24 after `pnpm install
--frozen-lockfile`, refuse on a failed build log, annotate the run, bootout,
poll `launchctl print`, bootstrap, wait for `/metrics`, run doctor and
resume the sessions the restart cut. `--dry-run` first when unsure. If a
recipe fails, stop and read its log; do not finish the restart by hand
with live sessions uncounted (`squad sessions`, every kind) or on a build
whose log says `recipe failed`. Log the restart (L7) with the log path.

Release (L8): squad is `direct` (lands on `main`; `trunk/v0.5` is retired;
`ci: none`). The release PR `chore(release): v0.5.x` (Cargo.toml,
Cargo.lock, both `package.json`, `tests/cli_broker.rs`, README, CHANGELOG
with a Rollout line naming broker parts not yet live) is queued with
`trunk.land {repo: "Exxo-Labs/gaia", pr, kind: "release"}` and
squash-merged by the service; tag; then `release-orchestrator` on Tim's go. The broker is not rebuilt here: that is Tim's
attended slot.

## Attended rebuild (broker) [L7]

With Tim at the keyboard, in this order, from `/Users/tim/dev/squad` on
`main`:

1. The orchestrator first: `just -f deploy/ops.Justfile
   release-orchestrator` (an orchestrator-only change stops here). The old
   orchestrator rejects the new broker's session list, so never rebuild the
   broker ahead of it.
2. `cargo install --path . --locked`.
3. Re-toggle App Management and Full Disk Access for the new binary in
   System Settings, Privacy & Security. The grants reset lazily (ENG-503):
   they reappear only when the binary first uses them, so check, do not
   assume. A throwaway task cannot prime the folder grants (a planner plans,
   it runs no commands).
4. `just -f deploy/Justfile install-launchd --yes` (the plists; it renders
   `dev.tim.squad-leader-watch` too but never starts it).
5. `just -f deploy/ops.Justfile restart-broker`: refuses while any session
   of any kind is mid-turn; `--force` only when the only busy session is
   the one running it. It prints sessions resumed against lost.
6. `squad doctor` all `ok`, `squad --version` the new build; then
   `leader-watch-start` (pre-flight row 9).

## Tunnel check

`devtunnel show <tunnel name> | grep "Host connections"`: 0 means the relay
is gone even when the pid lives and the public URL answers 302.
`launchctl kickstart -k gui/501/dev.tim.squad-tunnel` recovers it in about
12 s; log it (L7). The deps watcher raises a `policy:deps:tunnel:*` item
for the same outage.

## Kickoff brief shape

`claude-kickoff <prompt.md>` reads frontmatter `cwd`, `context`, `model`,
`effort`, `add_dirs` (and the lifetime and role keys the launcher
documents); the body is the brief. Launch in a window of tmux `main`:
`tmux new-window -t main -n <name> "claude-kickoff <file>"`. The body
restates what a fresh session cannot know: the secret-cache mechanics
(`agent/run -- <cmd>`, `agent-tooling cache status`), the repo's command
runner, explicit targets, SSH-only remotes, the worktree to use and how to
close it (`worktree-closedown`), the report path, and the trailers. Collect
results from the report file or `SendMessage`; close the window by name.

## Handover summary shape (memory, under about 60 lines)

Live build and `main` sha; every task and its state with what blocks it;
every live delegate (tmux window, brief path, what it does, what to do
with its report); open PRs with the next step each; authorities in force
by ruling id (round rulings included) and the merge scope row; the
leader-watch target (the successor restarts it with its own); what only Tim
can do, with the exact
line each; open `blocking: now` items; report file locations; a numbered
resume order (Tim's standing preference: hygiene first). Correct it as the
last reports land, then copy the memory dir again.
