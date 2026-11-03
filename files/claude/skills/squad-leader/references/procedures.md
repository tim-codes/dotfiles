# Leader procedures

Everything here is the fallback for something the squad should do itself.
Each use is an intervention (L-function in brackets). Written for squad
v0.5.14: orchestrator and broker both on it (`squad --version`, the
`squad doctor` version row).

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
3. **Build.** `squad --version` is the build that was tested; after any
   rebuild, App Management and Full Disk Access were re-toggled (Attended
   rebuild, below).
4. **Sessions.** `squad sessions`: no stale alive session (a planner of a
   rejected task, an exited member's mirror). Roster: no `done` member left
   unretired (ENG-525 automates this; until then, by hand, start and end).
5. **Pause.** tRPC `squad.state` is `{paused: null}`, or paused
   deliberately with a note Tim gave; never paused by accident.
6. **Repos.** tRPC `repos.list`: each repo of the batch registered with
   the right `trunk_policy` (squad and theparentedit `direct`) and
   `release_kind` (theparentedit `tag`, with workflow and URLs; others
   `none` unless a convention was registered).
7. **Plans.** Every task of the batch `approved`, its plan with structured
   `prerequisites` (no dependency in prose only), a `stage` on each
   deliverable, and a release convention for any `production` stage.
8. **Capture.** `squad debug on --run <run>`, then `runs.current` shows the
   run with `mode: debug` (Capture readiness, below).
9. **Presence and the ask.** `presence.set {attending: false}` as Tim
   leaves; the consolidated ask sent and answered.

## Item handling on an unattended night

Where to look first: the roster activity line ("is work happening?"; the
GUI member card, `roster.list`), then the todo card (ask the concierge;
`show_todo` is its tool: `Todo: N new, M can wait, K blocking`), then the
`blocking: now` items. "Alone" means under Tim's standing rules or a
ruling you cite; "park" means a line on Tim's list with the ready
proposal and exact command, the item left open. Log every action.

| Item | The leader decides alone | Parks for Tim | Never unattended |
|---|---|---|---|
| `stuck-<m>`, `blocked-<m>` | One concrete action (below) [L5, L6] | A wait only Tim can end (sign-in, grant, a decision no ruling covers) | Interrupt a session holding a heavy grant or mid-Bash; loosen a threshold |
| `policy:heal:<task>:<ref>` | Approve a heal-created task once its plan review passed (ruling 29) [L11] | The create-or-descope choice, with the item's proposal | Descope by wording or by editing the plan |
| `policy:deps:cache:*` (blocking now) | Check `squad doctor` and `agent-tooling cache status`; leave the hold (`deps_down`) standing | The item's commands and the re-warm (below) | Lift `hold_launches`; `docker rm` the cache; ad hoc `op` |
| other `policy:deps:*` | Tunnel kickstart (Tunnel check) [L7]; a `login` warn onto the morning list | A broker link down for three ticks, with `launchctl print` output | Restart the broker with sessions mid-turn |
| `policy:deps:broker_version:*` | Record which side is old | The attended rebuild, first on the morning list | `cargo install` or `restart-broker` unattended |
| `policy:release:<land>` (blocking now) | A `staging`-stage failure only (below) [L8] | A production (tag-run) failure, with re-run and rollback commands ready | Roll back, retag, delete a tag, set `release_kind` to `none` |
| `policy:release:<land>` (blocking later) | Nothing: `release_ready` is the approval repo's stop | The exact `git tag -a … && git push …` command | Run it |
| `policy:land:<task>` | Pass a fixable refusal on (below) | Third refusal, review timeout, `operator_only` or approval-repo merge | Merge an approval repo (h2gc); delete a branch; force-push |
| `policy:land:<task>:milestone:<id>` | `tasks.markLanded {milestone: true}` after Tim's merge [L2] | The merge, always | Merge a milestone |
| `pf-*` (preflight steps) | Deliver a step you can (deck, Boards publish) and `items.decide` with the result [L12] | Sign-ins, grants, anything needing Tim's hands | Grant TCC or a permission yourself |
| `r-*` (member raises) | `items.decide` under a cited ruling; the member acks [L4] | Anything needing Tim's judgment, with a proposal | Decide outside the rulings; re-ask a denied write in another form |

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
- **Release re-run.** Only when the item names the `staging` stage: one
  `gh run rerun <run> -R <repo> --failed`; the service carries on when it
  is green. Tim may widen this.
- **Land refusals.** A fixable refusal goes to the member; `tasks.markLanded`
  only after a merge Tim made.
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

## Landing a testable version by morning

The goal of an overnight batch: every task ends in one of three states.

- `done`: released to production on a `tag` repo (the concierge's
  "released to production" notice names tag and run), merged on the
  others; a `tag` repo needing approval also finishes `done`, with a
  `blocking: later` `release_ready` item on the land row naming the command.
- `landing`, with an open item for Tim naming the exact command (a merge
  Tim makes, a held release); a milestone waits on its merge item while
  the task runs on.
- Parked: a clear note on the task (what is parked, why, what unblocks it).

Nothing ends silently `running` or `blocked`. **Morning hand-back**, one
message, in this order:

1. Landed: per repo, task, PR, merge sha, and the tag plus run link (tag
   repos) or the merge (others).
2. Held: each item, why, and the exact command Tim runs.
3. Parked: deliverables and tasks, with the ruling or note.
4. Stalls and escalations: each `stuck-`/`blocked-` item, how long, how it
   cleared (supervision alone, or a leader action with its L-function).
5. Dependency incidents: each `policy:deps:*` item, the outage length,
   auto-start or not; the cache's `1Password items` count now and any
   re-warm done.
6. Open `blocking: now` items by id, and the asks that were unforeseeable.
7. Interventions L1–L13 with counts, and the `squad debug` bundle name
   (`debug/<run>/bundle/`) for the `squad-debug-review` lane.
8. State as left: paused or not (and why); `squad --version` and doctor's
   `version` row.

## Pause and resume

`just -f /Users/tim/dev/squad/deploy/ops.Justfile squad-pause <note>`
holds launches and messages (live sessions finish their task);
`squad-resume <note>` lets admission run at once. At the start of an
unattended run, pre-flight row 5 must find the squad unpaused or paused on
purpose. At the end, leave it as Tim asked: a pause you set for a restart
is lifted before you hand back; a pause he wants for his review is set with
a note and named in the hand-back.

## tRPC access

The orchestrator listens on `http://127.0.0.1:7790`. Sign in locally with
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
  -d '{"function":"L2","action":"milestone tim-codes/squad#277 refused by the classifier; command on Tim'"'"'s list","reason":"milestones are merged by hand (policy:land milestone item)","outcome":"handed_to_tim","pr":"tim-codes/squad#277"}'
```

Mutations the leader uses: `tasks.approve`, `tasks.markLanded`,
`items.decide`, `inbox.send`
(`{to: {member}, priority: 'now', kind: 'note', text}`), `sessions.resume`,
`sessions.close`, `presence.set`, `repos.put`, `ops.annotate`,
`operator.intervene`; queries `runs.current`, `runs.list`, `repos.list`,
`roster.list`, `squad.state`.

## Capture readiness check

```bash
squad debug on --run <run>    # writes <state>/debug.on (src/cmd/debug.rs: --run is a flag)
```

Then `runs.current` through tRPC: the run id with `mode: debug` and
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

Release (L8): squad is `direct` (lands on `main`; `trunk/v0.5` is retired).
The release PR `chore(release): v0.5.x` (Cargo.toml, Cargo.lock, both
`package.json`, `tests/cli_broker.rs`, README, CHANGELOG with a Rollout
line naming broker parts not yet live) squash-merges onto `main`; tag; then
`release-orchestrator`. The broker is not rebuilt here: that is Tim's
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
4. `just -f deploy/Justfile install-launchd --yes` (the plists).
5. `just -f deploy/ops.Justfile restart-broker`: refuses while any session
   of any kind is mid-turn; `--force` only when the only busy session is
   the one running it. It prints sessions resumed against lost.
6. `squad doctor` all `ok`, `squad --version` the new build.

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
by ruling id and the merge scope row; what only Tim can do, with the exact
line each; open `blocking: now` items; report file locations; a numbered
resume order (Tim's standing preference: hygiene first). Correct it as the
last reports land, then copy the memory dir again.
