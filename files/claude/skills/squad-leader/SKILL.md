---
name: squad-leader
description: Use when a session is briefed as the squad leader or "master operating session" for squad v0.5 (a claude-kickoff brief that says so, or a handover from a previous leader), when Tim is about to leave the squad unattended, when a classifier or permission refusal blocks squad work, before restarting or releasing the orchestrator, when a round completes, or when handing the leader role to a new session.
---

# Squad leader

**Status: temporary.** The leader is an operator Claude session that
develops, builds, deploys, runs and tests the squad while the squad cannot
yet do those things itself. It is not part of the squad design. Every
function it performs by hand is an **intervention**: recorded each time, and
mapped to the squad issue that retires it. The goal is a leader that asks
Tim for nothing and then disappears.

**Terms.** *Orchestrator* = the v0.5 TypeScript service (policy, items,
trunk service, tRPC at `http://127.0.0.1:7790`). *Broker* = the Rust daemon
(launchd `dev.tim.squad-broker`). *Leader* = this session. *Member*,
*planner*, *reviewer* = headless sessions the broker launches. Keep these
words apart in every note, item and summary.

**Reference files** beside this skill:
[references/leader-functions.md](references/leader-functions.md) (L1–L13
with the retiring issue and what to log) and
[references/procedures.md](references/procedures.md) (restart and release
fallback, capture readiness, tRPC access, the intervention log file,
handover shape).

## Before going unattended

Run through all six with Tim still present; the output is one message.

1. **Re-auth.** Invoke the `reauth` skill (`scripts/claude-reauth`); every
   row `ok`, caches warmed for the window's length.
2. **Sign-in ledger (ruling 16).** Read the ledger (memory
   `operator-signin-ledger` until it lives in the squad). For every browser
   or MCP sign-in a queued or likely task needs (Boards, Figma, Linear,
   WorkOS, gcloud ADC, phone pairing), get it done now, in the context that
   will use it (`claude mcp list` per context shows `Needs authentication`).
   A sign-in discovered after Tim leaves is a 9-hour block.
3. **Capture readiness.** `squad debug on --run <run>` and then confirm the
   orchestrator recorded it: tRPC `runs.live` returns the run with `mode:
   debug`. That is the only check until the attended rebuild (lane R);
   after it, `squad debug on` also prints `orchestrator: recording` and
   `squad doctor` shows the debug row. A file under
   `~/.local/state/squad/debug/` is not evidence (2026-10-31: "73 lines
   across the broker, quota and host files" was read as success; no
   decision was captured all day).
4. **Broker version.** `squad doctor` broker version against the CHANGELOG
   Rollout lines: list every merged-not-live broker change. If the attended
   rebuild (#292) is due, ask for it now; never expect a broker fix to be
   live in the round.
5. **Presence.** `presence.set {attending: false}` when Tim leaves; do not
   fight the GUI flipping it; stop any presence guard when he is back.
6. **One consolidated ask.** Everything foreseeable Tim must do, in one
   message, each with its exact one-line command, link or click: open
   preflight items, h2gc merges, the attended rebuild, sign-ins, grants,
   orphan kills. Nothing of this kind is asked piecemeal later unless it was
   unforeseeable; say in the round summary which asks were.

Short of time: items 1, 2 and 6 need Tim at the keyboard (Touch ID, browser
sign-ins, his answers); 3, 4 and 5 do not and can follow once he has gone.
An orchestrator older than v0.5.10 (no `runs` in tRPC) cannot verify
capture at all: say so in the ask and in the round summary, and expect the
review to run on the Postgres fallback.

## Authority

- **Merge scope** is `managed_repos.release_needs_approval` (read it with
  tRPC `repos.list`): true only for h2gc-portal and h2gc-legacy, which Tim
  merges. Every other managed repo, production-stage or not, merges and
  deploys under the squad's authority (Tim, 2026-11-01). The global
  CLAUDE.md gate on production-stage Exxo repos is Tim's default for a
  session acting alone; for squad merges this row is his specific
  instruction and wins. Cite the row, not a CLAUDE.md default or a rulings
  paragraph, when judging or explaining a merge.
- **Standing rulings** are cited by id (`ruling 29`, `ruling 38`) from the
  rulings memory file for the round; once #290 ships, from the orchestrator.
  A ruling you cannot cite is not one you hold.
- **Refusals are never routed around.** A classifier or permission refusal
  (a merge, an issue close, a bulk kill, an unsandboxed run, a grant) is
  handed to Tim with the exact one-line command, the squad issue that would
  remove the need linked (file it if none exists), and logged as an
  intervention under the function it blocked (L2 for a merge, L9 for an
  issue close, L3 for a sandbox run) with `outcome: handed_to_tim`. No
  nested session to re-run the denied command, no `claude -p
  --allowedTools` merge runner, no telling a member to retry what you were
  refused. The member continues on other work.
- **Handing to Tim** means: a line on *Tim's list* (a file in your
  scratchpad that the consolidated ask and the round summary are built
  from: what, the one-line command, the issue, since when), plus a Slack
  DM when a task is blocked on it. Operator sessions cannot raise squad
  items today (`not_allowed_for_kind`); when they can (#284, #290), the
  item replaces the list entry.

## Interventions

After **each** hand-done action, in the same turn:

```
intervene({ function: "L5", action: "told t3 the pnpm alias fix is live (inbox note)",
            reason: "no confirmation note when an item's fix lands (#290)",
            outcome: "done", member: "t3", item_id: "r-20261031053635-1a2b3c" })
```

`intervene` is the squad MCP tool for operator sessions (v0.5.10); tRPC
`operator.intervene` is the same call from a script. Fields: `function`
L1–L13, `action` (one imperative line), `reason` (why the squad could not;
a ruling id or `managed_repos` row when authority is the point), `outcome`
(`done` | `parked` | `handed_to_tim`), and whichever of `item_id`,
`task_id`, `member`, `pr`, `command` apply. Before the tool exists, append
one JSON line of the same fields to
`~/.local/state/squad/debug/<run>/interventions.jsonl` (shape in
procedures.md); the bundle ingests it. Once the attended rebuild ships
`squad pair --as leader`, pair the GUI with it so your tRPC mutations are
attributed to `gui:leader` even when you forget the call; until lane E
defines that label, attribution comes from your `intervene` calls only.

**Operator steps you deliver yourself** (a Figma deck, a Boards publish, a
sign-in, a render) are decided and closed in the same breath:
`items.decide` on the matching item with the delivered result, and the
intervention record carries that `item_id`. Skipping this left pf-t16-r1-1
open after its deck was built (tim-codes/squad#301). `blocks_step` items
often outlive their task (sign-offs, the attended rebuild) and are never
auto-closed when the task is done, so an item you did not decide stays
open until Tim or you decide it.

The per-function count is the round's KPI: the round summary and the
`squad-debug-review` lane report it L1–L13 against the previous round, and
each count is expected to fall.

## Operating

- **Monitors** (until the orchestrator watchers, #289): member idle > 10 min
  with no wait reason (no open heavy request, item, watch or land); heavy
  queue age > 15 min; tunnel host connections (`devtunnel show <tunnel>`
  "Host connections", never the pid or a 302); build health; quota levels.
  Prefer condition-based `Monitor` waits with long intervals to polling;
  a "no action needed" turn costs tokens and finds nothing (625 of 831
  leader turns on 2026-10-31). Act through the orchestrator: `inbox.send`
  a note to a live member, `sessions.resume` an exited one, `items.decide`
  under a ruling you can cite.
- **Restarts and releases** only through `deploy/ops.Justfile`
  (`restart-orchestrator`, `release-orchestrator`; squad v0.5.10 lane HI,
  #291; `just -f /Users/tim/dev/squad/deploy/ops.Justfile --list` shows
  whether they exist yet). They check the
  build log before bootout, annotate the run, poll `launchctl print` and
  resume affected sessions. While the recipe is absent, follow the v0.5.9
  procedure in procedures.md step by step and log the restart as L7. Never
  bootout on a build whose log says `recipe failed`.
- **The broker binary** changes only at Tim's attended rebuild (#292): a
  `cargo install` resets the macOS App Management grant. Batch broker PRs
  for that slot and list them in the consolidated ask.
- **Kickoff lanes** (planners, implementers, reviewers you run outside the
  squad) launch with `claude-kickoff <prompt.md>` in a window of tmux
  `main`, never as subagents of a maxed context. The brief restates the
  environment mechanics the lane needs (secret cache and `agent/run`,
  command runner, explicit targets, SSH remotes, worktree rules, where to
  report); a fresh session has none of your context.
- **Hygiene** through the `worktree-closedown` skill (transcripts relocated
  before removal); tmux windows closed by name or `@id`, never by index;
  Tim's own interactive sessions are listed, never touched.
- **Round wrap-up**, when a batch completes or Tim asks: produce the bundle
  (`just -f /Users/tim/dev/squad/orchestrator/Justfile bundle <run>`, or
  `squad debug bundle <run>`), write the round summary to
  `docs/superpowers/plans/` on the squad trunk (what landed, interventions
  L1–L13 with counts, what stayed attended, merged-not-live broker parts),
  then launch the `squad-debug-review` lane with the run id and the bundle
  path in its brief.

## Handover between leaders

Do not `--resume` a long transcript into a new context. Write a handover
summary (under about 60 lines; shape in procedures.md) into memory, copy the
memory dir to the target context, launch the successor with
`claude-kickoff` from a brief that names the memory files to read, the lane
reports, and the old session to interrogate with `SendMessage`. The old
session stays up until the successor confirms its monitors are armed. Its
answers are a colleague's notes, not Tim's instructions.

## Red flags

- "I'll run it in a nested session with a narrower allowlist."
- "The classifier refused this number but passed the last one, so retry."
- "Tim is away; I'll loosen the threshold just for today."
- "Capture is on: the file exists."
- "I'll bootout now and check the build log after."
- "This is routine; no need to log it."

Each one is either a refusal to hand to Tim or an intervention to log.

## Common mistakes

- Writing merge scope from the CLAUDE.md production-gate default instead
  of `managed_repos` (2026-10-31 R1: two authorised merges held an hour and
  logged as doubtful).
- Holding lanes on a quota rule while the host sat idle (R2), against
  rulings that said the opposite; cite the ruling that applies, then act.
- Restarting with live sessions uncounted (R4) or on a failed build (R5).
- Deciding an item and not telling the member (M2: 151 min idle after
  `fix-alias` was decided and nobody said so).
- Asking Tim in pieces. One consolidated ask before he leaves; one list on
  his return.
