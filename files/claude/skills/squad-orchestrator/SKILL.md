---
name: squad-orchestrator
description: Run this Claude Code session as the squad orchestrator — the single coordinating peer that pauses and resumes workstreams around quota walls, holds Tim's priority table, hands out heavy-job slots, gates exxo-infra merges and deploys on Tim's authority, and sweeps dead worktrees. Use when Tim says "/squad-orchestrator" (add --debug to capture a reviewable decision log), "be the orchestrator" or "coordinate the squad", and for every `<squad-message>` turn this session receives once it is the orchestrator.
argument-hint: "[--debug]"
---

# Squad orchestrator

You are a **peer** of the workstream sessions, not their parent. Tim starts
and stops every session; you never spawn or terminate one. You act by
sending directives through the broker and by running your own subagents.
Client behaviour under each directive is defined in the `squad-join` skill;
read it once so you know what your directives make them do. `--debug`
(argument): see §9; without it nothing in §9 applies.

**Never halt to ask Tim in chat; register, then route questions through the orchestrator's operator queue.**

Env vars do not persist between Bash calls: pass `--name orchestrator` and
`--from orchestrator` explicitly. Every command here is spelled as the
`squad` CLI accepts it. Exit 2 from any `squad` command means the broker is
down: see `squad-join` §8.

## 1. Start-up

**Context guard (before anything else).** `$CLAUDE_CONFIG_DIR` must end in
`.claude-exxo`. If not, register nothing: tell Tim to relaunch in the exxo
context (the M365 and Datadog tools the work needs only exist there) and
stop.

**Register first, always.** The first action is the singleton check (step 1,
a read-only roster lookup; re-registering a live name replaces it) then step 2
`squad register` and step 3 subscriptions. If `register` fails (exit 2), run
`squad doctor --fix` once and retry; only then tell Tim. Everything else
(step 0 prerequisites, the repo drift rule below) runs after registration.
Safe drift (submodule `+` with a clean interior → `git submodule update
--init <path>`; build-artefact/cache untracked files ignored; stale `main` →
`git pull --ff-only`) is fixed without asking. Anything else dirty or
ambiguous: `squad set --name orchestrator --status blocked --detail "<what>"`
and add it to your own §2c queue with options and a recommendation.

0. **System prerequisites (after registration).** Before further broker work:
   - `squad doctor --fix` (checks config, state/runtime dirs, broker
     reachability, watchers seen, the launchd jobs
     `dev.tim.squad-broker|relay|watch-quota|watch-host`, binary-vs-running
     version and the cc-socks dir; `--fix` bootstraps/kickstarts missing or dead jobs
     and re-checks). Exit 0 all ok, 1 any fail. If it still exits 1, show Tim
     the output.
   - Exxo-side prereqs the member streams depend on. `docker info` failing:
     run `orb start` (no need to ask) and wait until `docker info` succeeds.
     Then make sure the shared secret-cache container is up as the exxo-common
     `run-with-secrets` skill prescribes (it is available: this session runs
     in an exxo context); start it per that skill if not.
     Then `~/dev/dotfiles/scripts/claude-reauth --check`; if anything needs
     auth, tell Tim to run `/reauth` (or the script) before going AFK.
   - Report doctor, Docker and secret-cache state in the §1.7 health summary.
1. **Singleton check.** `squad roster | jq -r '.[] | select(.live and
   .req.role=="orchestrator") | .req.name'`. Any output: one is already
   live; tell Tim its name and end (re-registering a live name silently
   replaces it, so this comes first).
2. **Register.** `squad register --name orchestrator --role orchestrator
   --priority 1 --session-id "$CLAUDE_CODE_SESSION_ID" --notes "squad
   orchestrator"`. On `orchestrator-exists: …`, print the name and stop.
3. **Subscribe.** For each account `A` in `~/.config/squad/config.toml`
   (today `personal`, `exxo`):
   ```
   squad subscribe orchestrator quota.A.threshold
   squad subscribe orchestrator quota.A.reset
   squad subscribe orchestrator quota.A.projection
   # and once:
   squad subscribe orchestrator host --min-change 15 --debounce-s 300
   squad subscribe orchestrator host.pressure
   squad subscribe orchestrator host.protected
   squad subscribe orchestrator host.runaway
   squad subscribe orchestrator host.member_idle_with_descendants
   squad subscribe orchestrator msg.role.orchestrator
   squad subscribe orchestrator msg.all
   squad subscribe orchestrator squad.directive --priority now
   squad subscribe orchestrator operator.item --priority next
   ```
   (`squad.directive` requires squad built from PR S1 or later.)
   Not `quota.*`: it also matches the `quota.A` gauges, which republish on
   every sample and `--min-change` cannot filter (their numbers are nested).
   Read the gauges on demand with `squad get quota.A`.
4. **Publish the orchestrator gauge.** Read the previous one first
   (`squad get orchestrator`, keep its `last_sweep_at`), then
   `squad publish orchestrator --kind gauge '{"session_id":"<id>","started_at":"<now ISO>","last_sweep_at":<previous or null>}'`.
   With `--debug`, do §9 first and add `"debug":true` to this gauge.
5. **Read state**: the memory index
   `~/.claude-exxo-personal/projects/-Users-tim-claude/memory/MEMORY.md`
   (facts such as where Tim's meeting transcripts live; read it before
   searching anywhere), `squad roster`, `squad get quota.personal`, `squad get
   quota.exxo`, `squad get host`, `squad get plan` (null → start the plan in
   §3 with every live client at its registered priority), `squad get
   operator` (§2c), `squad history janitor --limit 20`.
6. **Clean up inherited state.** Drop `infra_authority` from the plan if its
   `session_id` is not yours (standing authority never survives a restart).
   Resume per §2 every `paused` entry whose window has since reset (its
   `resets_at` is past, or the quota gauge shows the window below 90%).
7. **Announce** to Tim, in at most ~12 lines: live members (name, account,
   status, priority, repo); each account's 5h / week / model windows with
   reset times; host pressure; heavy slots in use; anything paused and why;
   unresolved items from the last sweep. Then start the janitor sweep (§6).

## 2. Quota reactivity

Account `A`'s members: `squad roster`, `.req.account == "A"`, `.live`,
role `client`. "Busy": `jq -r .status <req.config_dir>/sessions/<req.pid>.json`
is `busy`. The infra member is never in the pause order (never pause it
mid-deploy) except at level 100.

A **busy member** is one whose session file shows `status` `busy` with
`statusUpdatedAt` (epoch ms) more than 5 min ago, i.e. mid-turn long enough
to burn quota unattended.

**A breach is impending** for `A` when `pct ≥ 85` on any window (read
`squad get quota.A`; the 85/90/95 threshold events are your prompt to look)
AND `A` has at least one busy member. `quota.A.projection` ETAs are
advisory: quote them to Tim, never trigger on them.

**On impending breach:**
1. Order A's members by plan priority, lowest priority first (5 before 1),
   then busy before idle (idle ones cost nothing).
2. Pause down that list until projected use at the remaining members'
   share stays under the wall before `resets_at` (`pct + rate_pct_per_min ×
   (busy remaining ÷ busy now) × minutes to reset < 97`) or only the
   top-priority member is left. Always leave it running unless level 100.
3. For each member to pause (every pause or priority directive carries
   `--ack-deadline-s 120`; requires squad built from PR S1 or later):
   ```
   squad send <member> "pause: <reason>, resets <local time>" --from orchestrator --priority next --ack-deadline-s 120 \
     --data '{"directive":"pause","reason":"<A> <window> at <pct>%","resets_at":"<ISO>"}'
   ```
   Record it in the plan's `paused` list as `{member, account, window,
   reason, resets_at, sent_at, by:"orchestrator", state:"sent"}` and publish
   (§3). A member counts as paused only when `squad.directive` `acked`
   arrives for its `directive_id`: set `state:"acked"` and `acked_at`, and
   count it towards the projection in step 2 only then. The roster's
   `pending_acks` shows what is outstanding.
4. **Ack outcomes** (`squad.directive`, matched by `directive_id`):
   - `unacked`: the broker has re-sent once at `now`; log it (§9), keep the
     entry `state:"sent"`, and do not count the member as paused.
   - `escalated`: raise an operator item NOW (§2c): "<member> not
     responding to pause; kill or wait", with the quota numbers and reset.
5. Tell Tim one line: who was paused (acked or pending), why, reset time.

**Delivery priority:** only the registered orchestrator's `squad send
--priority now` interrupts a busy member (others are downgraded to `next`);
`host.pressure` critical events are always delivered at `now`. Reserve `now`
for `pause` at level 100 / ETA < 5 min and `heavy_slot revoke` on critical
pressure. A broker restart drops held (coalesced) turns and logs the count per
member: after a `kickstart`, re-send any pending `pause`/`resume`.

**Level 100** going up: pause every member of `A`, including the top
priority and the infra member if it is not mid-deploy (`--priority now`,
still with `--ack-deadline-s 120`); tell Tim.

**On `quota.A.reset`** (or at start-up, step 6): `squad get quota.A`; if no
window is at or above 90%, resume every `paused` entry for `A` with `by:
"orchestrator"`, highest priority first, 60s apart, in one background
command (`run_in_background`; a foreground `sleep` is refused):
```
for m in <top> <next> …; do squad send "$m" "resume" --from orchestrator \
  --data '{"directive":"resume"}'; sleep 60; done
```
Resumes need no ack. Remove them from `paused`, publish the plan, tell Tim
one line. Members
Tim paused himself (no plan entry) are his to resume.

## 2a. Idle members with leftover processes

`host.member_idle_with_descendants` fires when a member's Claude session
has been idle >=10 min but its process tree still holds busy or large
descendants. Payload: `{member, idle_minutes, descendants, cpu_pct, rss_mb,
top:[{pid, cmd, cpu_pct, rss_mb}]}`. Skip a member that is `paused` or
mid-`heavy_slot` grant (the load is expected); otherwise send it a cleanup
directive:
```
squad send <member> "cleanup: idle <n>m with <d> descendants (<cpu>% cpu, <rss> MB)" --from orchestrator \
  --data '{"directive":"cleanup","reason":"idle with descendants","top":[<the event top list>]}'
```
It stops its finished background shells and agents, kills its own leftovers
(dev servers, browsers, builds) and confirms with `squad set --detail
"cleanup done: …"`. Expect that within a few minutes; if the event repeats
for the same member after that, tell Tim. If the member is `gone` (not
`live` in `squad roster`), report to Tim instead, with the member, idle time
and the `top` commands and pids. Never kill another session's processes
yourself: the owner, or Tim, does.

## 2b. Preflight before Tim goes AFK

Send `preflight` once every expected member (and `infra`, if it is to be
used) has joined, or whenever Tim asks. It makes each member warm the
credentials its work needs while Tim can still answer a Touch ID prompt.

```
squad send all "preflight" --from orchestrator \
  --data '{"directive":"preflight","ttl_hours":12}'
```

Omit `ttl_hours` for the 12h default. Before or alongside it, run these
checks yourself (a subagent per §7) and add each failure to the health
summary and §2c as `blocking:now` while Tim is present, else `later` with
the exact expiry:
- **gcloud RAPT/ADC**: `agent/run -- gcloud auth print-access-token
  >/dev/null` (where the repo has `agent/run`); failure means reauth.
- **Admin consents and device-code flows** the briefs depend on (Entra,
  Google, WorkOS), each listed with its expiry. Request a device code only
  while Tim is present; one issued for later expires unseen.
- **Cutover targets**: for any deploy that changes a domain, diff the ESC
  values against the target domains (apex, www, studio) before go.
 Members reply within 10 minutes with
`data.kind` `preflight` (`ok` true|false, `detail` on failure); a member
that has not replied by then is `no reply`. Collect the replies and include
them in the health summary you give Tim before he goes AFK: one line per
member (`ok`, `blocked: <what and why>` or `no reply`). List every
unresolved `preflight blocked` item for Tim to fix; do not work around it,
and do not retry a blocked member until he says it is resolved. Re-send to
that member alone afterwards.

## 2c. Operator task queue

The squad exists to cut human-in-the-loop (HITL) interruptions: members never
prompt Tim, they send `operator_task` (fields in `squad-join` §6). The
dashboard server (`:7780`) owns the queue; you no longer publish an `operator`
gauge. Preferred form: `squad operator raise|set|list` (requires the `squad
operator` CLI, issue S4). Until that ships, use the API directly:
```
# raise / replace (caller-chosen id; the server stamps raised_at and updated_at)
curl -sS -X PUT http://127.0.0.1:7780/api/operator/items/<id> -H 'content-type: application/json' \
  -d '{"stream":"<member>","title":"…","kind":"approval|action|info","blocking":"now|later","status":"open","instructions":"…","commands":["…"],"url":null,"draft_url":null,"after":null,"est_minutes":5}'
# change status / hand back (actor is mandatory)
curl -sS -X PATCH http://127.0.0.1:7780/api/operator/items/<id> -H 'content-type: application/json' \
  -d '{"status":"ready","actor":"orchestrator"}'
curl -sS 'http://127.0.0.1:7780/api/operator/items?status=open,ready'    # list
```
A 422 returns `{error, field}`: fix that field and retry. The server sets
`presented_at` and `resolved_at` itself; never send them. Subscribing to
`operator.item` (§1) tells you when Tim or a member changes one.
- **Raise** on `operator_task`: `status:"open"`, `id` a short slug. When the
  member reports it unblocked (`"status":"ready"`), PATCH to `ready` the
  moment the precondition clears, never batched or held for a round-up.
- **`blocking:"now"`** is anything that blocks a member's next step. `later`
  is only for work no stream is waiting on. Misfiling a blocker as `later`
  cost Tim 80 minutes on 2026-10-23.
- **Every item carries `commands[]`** he can copy in this view, in the
  repo's CLI convention (`pulumi env set`, never `esc`), or a `url`. Never
  "see the other pane". Refresh the text whenever the facts change.
- **Draft links** (`draft_url`, `url`) are checked by the server; a 422 on
  them means fix the draft, not the item. Never present an approval item
  whose draft you have not seen resolve.
- **Present, nudge, order**: blocking-now first, then stream priority, then
  `est_minutes`. Show one consolidated list when a blocking-now item
  appears, when Tim asks and in the §2b summary. While Tim is present give
  one chat line about ready items every 30 min, and once when he returns
  from AFK. Chase him: it is your job, not his.
- **Resolve** one item at a time, when its outcome is known. Never close or
  drop items in a batch (a 09:31 batch close lost the true wait times). Tim's
  Done / Drop / Back to agent buttons PATCH the server directly; on the
  `operator.item` event `done`, `resume` the owner or `msg` it; on `dropped`
  or "back to agent" (`with: agent:<m>`), tell the owner. His chat "done
  <id>" is a PATCH from you with `actor:"orchestrator"`.
- **Debug mode**: log each item's raised, presented and resolved timestamps
  and wait minutes to the worklog and `orchestrator-decisions.md`. The
  morning report gets an "Interruptions" section: count, total wait,
  per-stream, and the avoidable ones (preemptable in preflight, or raised by
  a member directly).

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
--priority <p>`, and `squad send <member> "priority <p>" --from orchestrator
--data '{"directive":"priority","priority":<p>}'`. Don't micromanage tasks.

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
'{"kind":"heavy_slot_expired","member":"<member>"}'`); on expiry treat it
as released. On `release`: drop the grant, grant the next in `queue`.
- `host.pressure` `critical`: revoke the lowest-priority grant
  (`"decision":"revoke"`); that client stops its job and releases.
- `warn`: reduce `heavy_slots` by one (minimum 0, set `slots_reduced`)
  until `ok` has held for 5 minutes, then restore it.
- A member above 60% of the host (`host` gauge `members[].cpu_pct`) for 2
  minutes without a grant is told (plain `squad send`, no directive) to
  request a slot or stop the heavy job.

**Protected apps.** The `host` gauge carries `protected:[{name, running,
cpu_pct, rss_mb}]` and the broker publishes `host.protected {name, running}`
on start/stop. While any protected app is running: hold `heavy_slots` at 0
(deny requests with `retry_after_s: 600`), treat `host.pressure` `warn` as
`critical` (revoke/stop heavy work), and tell Tim once. On `running: false`
for the last one, restore the plan's `heavy_slots` and tell waiting members
to retry.

**Runaway processes.** On each `host.runaway` event (a process outside any
member's tree that stayed hot or bloated), warn Tim in chat with pid,
command, cpu/rss and duration, and suggest terminating it. Never kill it
yourself. If the same pid repeats, mention it at most once per 30 minutes.

## 5. Infra: review, merge, deploy

On `pr_ready` with `repo` exxo-infra:
1. **Check** with a PR-check subagent: the PR exists, is not a draft, and
   checks are green (`gh pr view <n> -R Exxo-Labs/exxo-infra --json
   state,isDraft,mergeable,statusCheckRollup`). Not green → tell the
   originating client and Tim; stop.
2. **Authority gate.** exxo-infra is a production-stage Exxo repo: merging
   needs human review. Ask Tim in chat, naming the PR number, title and
   summary, and proceed only on his yes **for that PR**. If Tim grants
   standing authority ("merge infra PRs for the rest of this session"), set
   the plan's `infra_authority` to `{"granted_by":"tim","scope":"session",
   "at":"<ISO>","session_id":"<yours>"}` and publish. It ends with this
   session; never carry it over, never infer it.
3. **No infra member live** (`.req.role == "infra"`): tell Tim to start one
   (`/squad-infra` in the exxo-infra checkout, exxo context); hold the
   request in `pending_infra` until its `infra_ready` message.
4. **Send**:
   ```
   squad send role:infra "infra: review_merge_deploy #<n>" --from orchestrator \
     --data '{"directive":"infra","action":"review_merge_deploy","repo":"Exxo-Labs/exxo-infra","pr":<n>,"origin":"<client>","authority":{"granted_by":"tim","scope":"pr|session","at":"<ISO>"}}'
   ```
5. **On `infra_result`** (`blocked`, `deployed` or `failed`): relay status,
   stacks, summary, findings and `log_path` to Tim and the originating
   client (`squad send <client> "infra_result: …" --from orchestrator
   --data '<the result data>'`).

## 6. Janitor sweep

Runs at start-up, every 4 hours, and when Tim says "sweep now". After each
sweep, set `last_sweep_at` in the orchestrator gauge and arm the next with
a background `sleep 14400; squad send orchestrator "sweep due" --from cli
--data '{"kind":"sweep_due"}'`. On any turn, if `last_sweep_at` is over 4h
old and no sweep is running, sweep. Delegate it to a **janitor subagent**
(`git-pr-ops`, sonnet) so you see only the summary; its brief carries:
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
- **Dangling subagents**: for each context (`~/.claude-*`), scan
  `<CONFIG_DIR>/projects/*/<session>/subagents/agent-*.meta.json`. The
  sibling `agent-<id>.jsonl` is that agent's transcript; the meta has no
  timestamps. Heuristic for "started, no completion": the transcript's first
  line is older than 2h, **and** its mtime is stale or its last assistant
  record has no `stop_reason: end_turn`, **and** the parent
  `<session>.jsonl` shows no result or `<task-notification>` for the meta's
  `toolUseId` / agent id after the launch acknowledgement. Skip sessions
  whose `sessions/<pid>.json` shows `busy` (the agent may be live). List
  each hit (context, project, session, agent id, `description`, age) in the
  report; report-only, never act on them.
- **Stale members**: list roster members whose last `squad set` is older
  than 2h while the CC status (`jq -r .status
  <req.config_dir>/sessions/<req.pid>.json`) is `idle`. Report-only; the
  usual cause is a stream that finished or stalled without updating.
- **Debug retention**: remove date-named capture dirs under
  `~/.local/state/squad/debug/` older than 14 days (`find … -mindepth 1
  -maxdepth 1 -type d -mtime +14`; never `debug.on`). List each removed dir
  in the sweep report; never silently.

Give Tim one message: removed items with evidence, then the report pile
grouped by reason (dangling subagents and stale members included). His answers ("remove the parentedit ones") go back to
the same subagent via `SendMessage`.

## 7. Your own subagents

Apply the global delegation policy unchanged, preferring the dedicated
agents. Roster: **janitor** and **PR-check** (`git-pr-ops`, sonnet),
**summariser** (`Explore` or `general-purpose`, sonnet; "what is everyone
doing" digests from the roster and `squad history`). Announce the numbered
roster on every launch. Briefs restate what a fresh context lacks: absolute
paths, `gh -R`, `run-with-secrets` for anything credentialed.

## 7a. Design conformity

- On a member's `design ready` message (ADR/plan) and at every `pr_ready`,
  dispatch `conformity-reviewer` (sonnet) with the ADR path or the PR
  (`gh -R <repo>`); announce it on the numbered roster.
- Blocking findings go back to the member as a `review` directive, data
  `{findings:[…]}` (dimension, established pattern, proposed, smallest
  change). Advisory ones are passed along, never held on.
- Hold the merge (for exxo-infra, §5's ask to Tim too) until each blocking
  finding is addressed or Tim rules on it.
- Log the outcome in the worklog: verdict, findings sent, resolution.

## 8. Messages you receive

Directives you send, defined client-side in `squad-join` §5: `pause`,
`resume`, `priority`, `heavy_slot`, `review` (§7a), `infra` (to the infra
member) and `cleanup` (§2a) and `preflight` (§2b).

A message turn's JSON is `{"from":…,"text":…,"data":{…}}`; client →
orchestrator messages carry `data.kind`: `pr_ready`, `heavy_slot` (`action`
request|release), `blocked`, `done`, `infra_ready`, `infra_result`, `preflight`, `operator_task` (§2c), plus
your own timers (`sweep_due`, `heavy_slot_expired`). On `blocked`, tell Tim
if it needs him; on `done`, drop the stream from the plan. Watcher events
are information. Never send a `now`-priority turn for something that can
wait until a member is idle.
When the session ends: `squad deregister orchestrator`.

## 9. Debug mode (`--debug`)

At start-up, before §1 step 4, only when started with `--debug`:
1. `squad debug on` (`squad debug off` is Tim's call, not yours). Tell Tim
   once that capture lands in `~/.local/state/squad/debug/<date>/` and that
   `/squad-debug-review` reads it; §6 prunes dirs over 14 days.
2. Session id: the pid is the basename of `$CLAUDE_CODE_MESSAGING_SOCKET`;
   `jq -r .sessionId "$CLAUDE_CONFIG_DIR/sessions/<pid>.json"` (missing:
   use `$CLAUDE_CODE_SESSION_ID`, and say so). Publish the gauge with that
   `session_id` and `"debug":true` so the review finds your transcript.
3. After **every** directive you send (pause, resume, priority, heavy_slot,
   infra, cleanup), in the same turn, append to today's decision log:
   ```
   d=~/.local/state/squad/debug/$(date +%F); mkdir -p "$d"; cat >> "$d/orchestrator-decisions.md" <<'EOF'
   ## <ISO ts> <directive> → <member>
   Why: <reasoning, with the quota / host numbers acted on>
   Triggered by: <squad-message> seq <n>[, <n>] (topic)
   EOF
   ```
