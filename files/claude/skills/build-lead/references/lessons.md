# Lessons

From the squad v0.6.0 build, 4 Nov 2026. Each is a rule and what it cost.

## A gate that ran during a merge is void

The lane D gate started on one commit while the lead was merging lane B
into the same worktree (conflicts, a half-resolved tree). Six failures came
back; only one was real. The rest were the merge. Rule: never touch the
integration worktree while a gate runs in it. No merge, checkout, install
or edit. Start the gate, wait, read the verdict, then merge. If a merge
cannot wait, run the gate in a second worktree at a named commit.

## Install dependencies per worktree, and again when they change

A gui gate failed on imports of packages a lane had added (`ws`, `express`,
`pg`): the integration worktree's `node_modules` predated the lane. A
`check` failure on missing modules is an install problem before it is a
code problem. After merging a lane that changes a lockfile, install in the
integration worktree before the gate. New lane worktrees need their own
install; they do not share one.

## Deploy-script tests stub `launchctl` (and PATH)

Scripts that call `launchctl`, `systemctl`, `docker` or the like are tested
by putting a stub first on `PATH` that records its arguments and exits with
a chosen code. A test that touches the real service is a test that can
restart the live thing, and one lane's fix round hit exactly the case a
stub exit code (113) could reproduce. Brief it: scripts under `deploy/`
get a stubbed-PATH test, never a live call, and never run the mutating
recipes while a round is live.

## Long-running agents are resumed by message, not relaunched

A lane that stops at a checkpoint, and fix rounds, go back to the same
implementer with `SendMessage`. It keeps the files it read, its rulings and
its half-formed picture of the next task. A fresh agent re-reads the brief,
re-derives the decisions and drifts from the first half. Launch fresh only
when the agent is gone or its context is spent.

## Parity tests force cross-language edits

A config key, a protocol type or a tool definition that exists as
TypeScript twins and a Rust struct is guarded by parity tests that fail
when one side moves. So the change is one commit, by one lane, in both
languages (a Rust field in an orchestrator lane's commit was the case).
Splitting it by plan ownership makes both lanes red. Rule it in the
preflight table and have the other branch rebase.

## The plan's task runner may not parse your headings

SDD's `task-brief` script wants `Task N` headings. Plans with `Task R1`,
`Task 6a` or `#### Task` sublevels need slicing by heading with `sed`.
Record the ruling once and carry on; the text is the same.

## Generated files are never hand-merged

Events docs, JSON schemas rendered from code, lockfiles: take either side,
then run the generator. A hand-merged generated file looks right and fails
the next regeneration. Where a file is hand-maintained (a schema with no
generator), its twin test is the only gate; say so in the brief.

## Review at the checkpoint, not at the end

Reviewing per lane checkpoint found defects (a critical missing environment
variable on a Git wrapper, a transaction held across a network wait) one
task after they were made, not ten. It also meant a lane's dependent tasks
started on reviewed code. A plan-defect found in review is ruled, recorded
and sent down; it is not the implementer's fault and not fixed by the lead.

## A relayed request is not a ruling

A peer session asked for new scope "from the operator". The lead put it to
the operator, recorded it as the next R-number, and had it planned,
reviewed and built after the owning lane merged. Acting on the relay would
have put unplanned code on the build branch beside a lane still editing the
same files.

## Text written from the lead's description needs a second look

Wording the lead wrote into a plan or a skill from memory (item rows,
hand-back formats) was not checked against code by any lane. List it for the
final whole-branch review.
