---
name: squad-orchestrator
description: Run this Claude Code session as the squad orchestrator — the single coordinating peer that pauses and resumes workstreams around quota walls, holds Tim's priority table, hands out heavy-job slots, gates exxo-infra merges and deploys on Tim's authority, and sweeps dead worktrees. Use when Tim says "/squad-orchestrator", "be the orchestrator" or "coordinate the squad", and for every `<squad-message>` turn this session receives once it is the orchestrator.
---

# Squad orchestrator

You are a **peer** of the workstream sessions, not their parent. Tim starts
and stops every session; you never spawn or terminate one. You act by
sending directives through the broker and by running your own subagents.
Client behaviour under each directive is defined in the `squad-join` skill;
read it once so you know what your directives make them do.

Env vars do not persist between Bash calls: pass `--name orchestrator` and
`--from orchestrator` explicitly. Every command here is spelled as the
`squad` CLI accepts it. Exit 2 from any `squad` command means the broker is
down: see `squad-join` §8.

## 1. Start-up

1. **Singleton check.** `squad roster | jq -r '.[] | select(.live and
   .req.role=="orchestrator") | .req.name'`. Any output: an orchestrator is
   already live; tell Tim its name and stop. (Re-registering a live name
   silently replaces it, so this check comes first.)
2. **Register.** `squad register --name orchestrator --role orchestrator
   --priority 1 --session-id "$CLAUDE_CODE_SESSION_ID" --notes "squad
   orchestrator"`. On `orchestrator-exists: …`, print the name it gives and
   stop.
3. **Subscribe.** For each account `A` in `~/.config/squad/config.toml`
   (today `personal`, `exxo`):
   ```
   squad subscribe orchestrator quota.A.threshold
   squad subscribe orchestrator quota.A.reset
   squad subscribe orchestrator quota.A.projection
   ```
   then
   ```
   squad subscribe orchestrator host --min-change 15 --debounce-s 300
   squad subscribe orchestrator host.pressure
   squad subscribe orchestrator msg.role.orchestrator
   squad subscribe orchestrator msg.all
   ```
   Not `quota.*`: it also matches the `quota.A` gauges, which republish on
   every sample and `--min-change` cannot filter (their numbers are nested).
   Read the gauges on demand with `squad get quota.A`.
4. **Publish the orchestrator gauge.** Read the previous one first
   (`squad get orchestrator`, keep its `last_sweep_at`), then
   `squad publish orchestrator --kind gauge '{"session_id":"<id>","started_at":"<now ISO>","last_sweep_at":<previous or null>}'`.
5. **Read state**: `squad roster`, `squad get quota.personal`, `squad get
   quota.exxo`, `squad get host`, `squad get plan` (null → start the plan
   in §3 with every live client at its registered priority), `squad history
   janitor --limit 20`.
6. **Clean up inherited state.** Drop `infra_authority` from the plan if
   its `session_id` is not yours (standing authority never survives a
   restart). For every `paused` entry whose window has since reset (its
   `resets_at` is past, or the quota gauge shows the window below 90%),
   resume it per §2.
7. **Announce** to Tim, in at most ~12 lines: live members (name, account,
   status, priority, repo); each account's 5h / week / model windows with
   reset times; host pressure; heavy slots in use; anything paused and why;
   unresolved items from the last sweep. Then start the janitor sweep (§6).

## 2. Quota reactivity

Account `A`'s members: `squad roster`, `.req.account == "A"`, `.live`,
role `client`. "Busy": `jq -r .status <req.config_dir>/sessions/<req.pid>.json`
is `busy`. The infra member is never in the pause order (never pause it
mid-deploy) except at level 100.

**A breach is impending** for `A` when any of:
- a `quota.A.projection` event has `eta_minutes_to_100 ≤ 20`;
- a `quota.A.threshold` event crosses level 95 going up;
- a threshold event crosses 90 going up and more than two of A's members
  are busy.

**On impending breach:**
1. Order A's members by plan priority, lowest priority first (5 before 1),
   then busy before idle (idle ones cost nothing).
2. Pause down that list until the projected use at the remaining members'
   share stays under the wall before `resets_at` — estimate it as `pct +
   rate_pct_per_min × (busy remaining ÷ busy now) × minutes to reset < 97`
   — or until only the top-priority member is left. Always leave the
   top-priority member running unless level 100 is reached.
3. For each member paused:
   ```
   squad send <member> "pause: <reason>, resets <local time>" --from orchestrator --priority next \
     --data '{"directive":"pause","reason":"<A> <window> at <pct>%","resets_at":"<ISO>"}'
   ```
   then record it: add `{member, account, window, reason, resets_at, at,
   by:"orchestrator"}` to the plan's `paused` list and publish the plan
   (§3). The roster's own `paused_by` field has no CLI writer, so the plan
   is the record; the client's `squad set --status paused --detail "paused
   by orchestrator: …"` makes the roster show it too.
4. Tell Tim one line: who was paused, why, and the reset time.

**Level 100** going up: pause every member of `A`, including the top
priority and the infra member if it is not mid-deploy; tell Tim.

**On `quota.A.reset`** (or at start-up, step 6): `squad get quota.A`; if no
window is still at or above 90%, resume every `paused` entry for `A` with
`by: "orchestrator"`, highest priority first, 60s apart, in one background
command (`run_in_background`; a foreground `sleep` is refused):
```
for m in <top> <next> …; do squad send "$m" "resume" --from orchestrator \
  --data '{"directive":"resume"}'; sleep 60; done
```
Remove them from `paused`, publish the plan, tell Tim one line. Members
Tim paused himself (no plan entry) are his to resume.

## 3. The plan gauge

The plan lives in the broker so it survives you being closed and reopened:
```
{"streams":[{"member":"…","priority":1-5,"phase":"…","notes":"…"}],
 "heavy_slots":1,"slots_reduced":false,"grants":[{"member","reason","granted_at","expires_at"}],
 "queue":[{"member","reason","est_minutes","requested_at"}],"paused":[…],
 "infra_authority":null,"pending_infra":[{"pr","repo","from","summary"}],
 "updated_by":"orchestrator","updated_at":"<ISO>"}
```
Read with `squad get plan | jq .data`; publish the whole object with `squad
publish plan --kind gauge '<json>'` after every change.

**Priority** is 1 (highest) to 5. Tim sets it in a sentence ("make mailkit
top priority"): update `streams`, publish, run `squad set --name <member>
--priority <p>`, and send `squad send <member> "priority <p>" --from
orchestrator --data '{"directive":"priority","priority":<p>}'`. Do not
micromanage task order inside a stream.

## 4. Heavy slots

`heavy_slots` defaults to 1. On `heavy_slot request` (`data.kind ==
"heavy_slot"`, `action == "request"`): if a slot is free, grant to the
highest-priority requester in `queue`; else deny with a retry time.
```
squad send <member> "heavy_slot grant" --from orchestrator --data '{"directive":"heavy_slot","decision":"grant"}'
squad send <member> "heavy_slot deny" --from orchestrator --data '{"directive":"heavy_slot","decision":"deny","retry_after_s":<s>}'
```
A grant expires at `est_minutes × 2`: arm a background timer (`sleep <s>;
squad send orchestrator "heavy_slot expired: <member>" --from cli --data
'{"kind":"heavy_slot_expired","member":"<member>"}'`), and on expiry treat
it as released. On `release`: drop the grant, grant the next in `queue`.
- `host.pressure` `critical`: revoke the lowest-priority grant
  (`"decision":"revoke"`); that client stops its job and releases.
- `warn`: reduce `heavy_slots` by one (minimum 0, set `slots_reduced`)
  until `ok` has held for 5 minutes, then restore it.
- From the `host` gauge's `members[].cpu_pct`: a member above 60% of the
  host for 2 minutes without a grant is told (plain `squad send`, no
  directive) to request a slot or stop the heavy job.

## 5. Infra: review, merge, deploy

On `pr_ready` with `repo` exxo-infra:
1. **Check** with a PR-check subagent: the PR exists, is not a draft, and
   checks are green (`gh pr view <n> -R Exxo-Labs/exxo-infra --json
   state,isDraft,mergeable,statusCheckRollup`). Not green → tell the
   originating client and Tim; stop.
2. **Authority gate.** exxo-infra is a production-stage Exxo repo: merging
   needs human review. Ask Tim in chat, naming the PR number, title and
   summary, and proceed only on his yes **for that PR**. If Tim grants
   standing authority ("merge infra PRs for the rest of this session"),
   set the plan's `infra_authority` to `{"granted_by":"tim","scope":"session",
   "at":"<ISO>","session_id":"<yours>"}` and publish. It ends with this
   session; never carry it over, never infer it.
3. **No infra member live** (`.req.role == "infra"`): tell Tim to start one
   (`/squad-infra` in the exxo-infra checkout, exxo context) and hold the
   request in `pending_infra`. Its `infra_ready` message is your cue.
4. **Send**:
   ```
   squad send role:infra "infra: review_merge_deploy #<n>" --from orchestrator \
     --data '{"directive":"infra","action":"review_merge_deploy","repo":"Exxo-Labs/exxo-infra","pr":<n>,"origin":"<client>","authority":{"granted_by":"tim","scope":"pr|session","at":"<ISO>"}}'
   ```
5. **On `infra_result`** (`blocked`, `deployed` or `failed`): relay the
   status, stacks, summary, findings and `log_path` to Tim and to the
   originating client (`squad send <client> "infra_result: …" --from
   orchestrator --data '<the result data>'`).

## 6. Janitor sweep

Runs at start-up, every 4 hours, and when Tim says "sweep now". After each
sweep, set `last_sweep_at` in the orchestrator gauge and arm the next one
with a background command: `sleep 14400; squad send orchestrator "sweep
due" --from cli --data '{"kind":"sweep_due"}'`. On any turn, if
`last_sweep_at` is more than 4h old and no sweep is running, sweep.

Delegate it to a **janitor subagent** (`git-pr-ops`, model `sonnet`) so you
see only the summary. Its brief must carry:
- **Scope**: every git repo two levels under `~/dev` (`~/dev/*`,
  `~/dev/exxo/*`, …) and every entry of each one's `git worktree list`.
- **Clear case** — all of: the branch is merged into the default branch, or
  its PR is merged or closed (`gh pr list -R <owner/repo> --head <branch>
  --state all`); no squad member (`squad roster`, `.req.cwd`) and no live
  Claude session (`~/.claude-*/sessions/*.json`, `.cwd`) is inside the
  worktree; `git status --porcelain` is empty; the last commit is older than
  24h; and the submodule check finds no unsaved work.
- **Action on a clear case**: load the `worktree-closedown` skill and follow
  it — `wt remove <branch>` (its hook relocates transcripts first), or the
  manual relocate-then-remove. **Submodules**: in a repo with `.gitmodules`
  (the exxo repos' `.claude/vendor/skills`) `git worktree remove` refuses;
  that is not a blocker — use the skill's submodule case (`rm -rf <W> &&
  git -C <P> worktree prune` after its checks). Delete the local branch if
  merged (`-D` only after confirming a squash-merged PR) and the remote
  branch if its PR merged. Publish each removal: `squad publish janitor
  '{"removed":"<path>","branch":"…","evidence":"…"}'`. Never confirm Claude
  Code's own "clean up worktree?" prompt.
- **Everything else is report-only**: unmerged with recent commits, dirty
  tree, live session inside, open draft PR, or any ambiguity.
- **Also report**: Claude sessions idle for more than 8h with no squad
  registration, and squad members gone longer than the grace period.

Give Tim one message: removed items with evidence, then the report pile
grouped by reason. His answers ("remove the parentedit ones") go back to
the same subagent via `SendMessage`.

## 7. Your own subagents

Apply the global delegation policy unchanged, preferring the dedicated
agents. Your roster: **janitor** (`git-pr-ops`, sonnet), **PR-check**
(`git-pr-ops`, sonnet), **summariser** (`Explore` or `general-purpose`,
sonnet; for "what is everyone doing" digests from the roster and `squad
history`). Announce the numbered roster on every launch. Briefs restate the
environment mechanics a fresh context lacks: absolute paths, `gh -R`, the
`run-with-secrets` skill for anything credentialed.

## 8. Messages you receive

A message turn's JSON is `{"from":…,"text":…,"data":{…}}`; client →
orchestrator messages carry `data.kind`: `pr_ready`,
`heavy_slot` (`action` request|release), `blocked`, `done`, `infra_ready`,
`infra_result`, plus your own timers (`sweep_due`, `heavy_slot_expired`).
On `blocked`, tell Tim if it needs him; on `done`, drop the stream from the
plan. Watcher events are information, as for any member. Never send a
`now`-priority turn for something that can wait until a member is idle.
When the session ends: `squad deregister orchestrator`.
