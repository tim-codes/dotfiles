# Leader procedures

Everything here is the fallback for something the squad should do itself.
Each use is an intervention (L-function in brackets).

## tRPC access

The orchestrator listens on `http://127.0.0.1:7790`. Locally,
`GET /auth/local` issues the operator cookie; then call
`/trpc/<router>.<procedure>`. Mutations the leader uses: `tasks.approve`,
`tasks.markLanded`, `items.decide`, `inbox.send`
(`{to: {member}, priority: 'now', kind: 'note', text}`), `sessions.resume`,
`sessions.close`, `presence.set`, `repos.put`; from v0.5.10 `runs.live`,
`ops.annotate`, `operator.intervene`. Pair the GUI with
`POST /auth/pair` (v0.5.10: `squad pair --as leader`, so the cookie maps to
actor `gui:leader`); the minted URL is relative when `public_url` is unset,
so prefix the tunnel origin yourself.

## Capture readiness check

```bash
squad debug on <run>          # writes <state>/debug.on; v0.5.10 CLI also polls the orchestrator
squad doctor                  # debug row: run id, mode, orchestrator recording
```

Then `runs.live` through tRPC: the run id with `mode: debug` and
`started_at` is the proof. If `runs.live` shows the implicit `auto-<date>`
run or nothing, the orchestrator did not notice the switch: check it is the
v0.5.10 build (`orchestrator.started` event, `squad doctor` version), and
fix that before declaring the round started. An orchestrator older than
v0.5.10 has no `runs` at all: capture cannot be verified, say so, and the
review runs on the Postgres fallback. The broker sinks (`host.jsonl`,
`quota.jsonl`) prove nothing about the orchestrator.

## Intervention log file (before the `intervene` tool exists)

Path: `~/.local/state/squad/debug/<run>/interventions.jsonl`, where `<run>`
is the basename of `squad debug dir`. One JSON object per line, appended
with `>>`; the bundle ingests it beside `interventions.csv` and labels the
rows `leader-file`. Fields match the `leader.intervention` event:

```json
{"ts":"2026-11-02T10:12:00Z","function":"L2","action":"merged tim-codes/squad#277 (checkpoint)","reason":"trunk service does not land framework PRs; ruling 38","outcome":"done","pr":"tim-codes/squad#277","item_id":null,"task_id":null,"member":null,"command":null,"session_id":"<leader session id>","actor":"leader"}
```

`ts` is UTC ISO-8601; `outcome` is `done`, `parked` or `handed_to_tim`;
unused ids are `null`, not omitted. Never put a token, password or secret
value in `action`, `reason` or `command`.

## Restart and release the orchestrator [L7, L8]

Preferred: `just -f /Users/tim/dev/squad/deploy/ops.Justfile
restart-orchestrator` and `release-orchestrator` (lane HI; #291). They run
the build on Node 24 with `pnpm install --frozen-lockfile` first, refuse on
a failed build log, annotate the run (`ops.annotate`), bootout, poll
`launchctl print` until the job is gone, bootstrap, wait for `/metrics`,
and resume sessions the restart cut.

Fallback (the v0.5.9 procedure, by hand, each step checked), only after
`just -f /Users/tim/dev/squad/deploy/ops.Justfile --list` confirms the
recipe is absent rather than mistyped:

1. Count live sessions of every kind (`squad sessions`, not members only:
   on 2026-10-31 a restart "with busy=0" cut three planners and a
   reviewer). Prefer a moment when nothing is mid-turn; otherwise expect to
   resume them.
2. In `/Users/tim/dev/squad` on the release commit: `pnpm install
   --frozen-lockfile` in `orchestrator/` and `gui/` on Node 24 (a new
   dependency with stale `node_modules` broke the v0.5.5 restart).
3. `just -f /Users/tim/dev/squad/orchestrator/Justfile build` and
   `just -f /Users/tim/dev/squad/gui/Justfile build`, output to a log file;
   grep the log for `recipe failed`, `Rollup`, `ERR_MODULE_NOT_FOUND`. Any
   hit: stop, no bootout (v0.5.5 build 055 was booted out on a failed
   build; a member idled 55 min).
4. `launchctl bootout gui/501/<orchestrator label>` (both labels and their
   state: `just -f /Users/tim/dev/squad/deploy/Justfile check-launchd`).
5. Poll `launchctl print gui/501/<orchestrator label>` until it reports
   not found (bootout returns early; a bootstrap 3 s later failed with
   "Input/output error 5" and left the job down).
6. `launchctl bootstrap gui/501 ~/Library/LaunchAgents/<orchestrator label>.plist`.
7. `squad doctor` exit 0; migrations applied at start; GUI answers on 7790;
   `runs.live` still shows the debug run.
8. `sessions.resume` every session the restart ended (`lost`, or a member
   whose land was refused during the gap); send each a one-line note on
   what changed.
9. Log the restart (L7) with the build log path and the version.

Release (L8): release PR `chore(release): v0.5.x` on the trunk (Cargo.toml,
Cargo.lock, both `package.json`, `tests/cli_broker.rs`, README, CHANGELOG
with a Rollout line naming merged-not-live broker parts); checkpoint PR
trunk→main with a merge commit, never a squash; tag; then the restart
above. The broker binary is not rebuilt: that is Tim's attended slot
(#292), and `cargo install --path . --locked` resets the macOS App
Management grant that he must re-toggle.

## Tunnel check

`devtunnel show <tunnel name> | grep "Host connections"`: 0 means the relay
is gone even when the pid lives and the public URL answers 302.
`launchctl kickstart -k gui/501/dev.tim.squad-tunnel` recovers it in about
12 s; log it (L7) and note it for #289.

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

Live build and trunk sha; every task and its state with what blocks it;
every live delegate (tmux window, brief path, what it does, what to do
with its report); open PRs with the next step each; authorities in force
by ruling id and the merge scope row; what only Tim can do, with the exact
line each; monitors to re-arm; report file locations; a numbered resume
order (Tim's standing preference: hygiene first). Correct it as the last
reports land, then copy the memory dir again.
