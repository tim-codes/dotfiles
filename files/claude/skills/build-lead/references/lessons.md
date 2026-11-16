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

# From the Gaia v0.7.5 build, 16 Nov 2026

## A lane that touches a second package needs that package's gate

A lane changed two GUI label maps but could not run the GUI typecheck (no
`node_modules`), and said so in its report. A third map in `glossary.ts`
was missed and the PR's CI went red. Rule: when a report says "X not run",
that is a gate gap. The lead puts X in the light gate: install the package
and run its check recipe.

## Contract tests belong in the light gate when a lane adds procedures or events

A query procedure passed the lane's own tests but failed a contract test
elsewhere (`contracts/actionApi.test.ts`) that pins "only X is a query".
Rule: after a merge that adds tRPC procedures or events, run the contract
and registry tests, not just the lane's files.

## Tests that start real servers can load the operator's config

Rust tests started private tmux servers that read `~/.tmux.conf` (TPM,
resurrect). One restored the operator's 197-pane session, load passed 190,
and resurrect saves piled up. Rule: before running a repo's integration
tests on the operator's workstation, check that test servers start with no
user config (`-f /dev/null` for tmux). Until then, run only filtered tests.

## When lanes stall, check the host before the code

`testlock` also waits for the 1-minute load to drop under its ceiling, and
a repo's heavy-slot gate can be blocked by a stale request whose holder
died. Rule: when several lanes report "waiting on background work", check
the load average, the testlock owner file and the heavy queue's head first.

## A gate script passes arguments as arrays

A light-gate script passed `"--lib name"` as one argument, cargo rejected
it, and the "red" gate was void. Rule: build commands with `"$@"` or
arrays, and read a red gate's first error before dispatching a fix.

## Check what triggers CI before deciding when to push

In a repo whose CI runs only on PRs, `main` and dispatch, a push of the
build branch wakes nothing, so checkpoint pushes are free off-machine
copies. Rule: read the workflow `on:` blocks at setup and record the push
policy in the ledger.

## The ledger lives in a gitignored worktree directory

SDD's `.superpowers/sdd/` sits in the integration worktree, so closedown
deletes it. Rule: copy the ledger to durable scratch before closedown.

## A subagent's second hand-back is refused

When an agent reports twice, the second report is dropped ("one report per
result"). Rule: when the notice says a hand-back was refused, ask the agent
to resend in a few lines. Don't assume it said nothing.

# From the Gaia v0.7.7 build, 16 Nov 2026

## Some contexts refuse PR and CI commands, so plan the hand-over

In the reserve context the permission system refused `gh pr create` and
`gh run rerun` (for the gaia PR, a dotfiles PR and a rerun of flaky jobs).
Rule: expect this at setup. At the end, write the PR body to a file and send
the operator session the exact command (identical in fish and bash) for Tim to
run. Do the same for a rerun. Don't retry or work around a refusal.

## The end-of-build PR must be ready, not a draft, for the full gate to run

Gaia's `ci.yml` skips draft PRs (`github.event.pull_request.draft != true` on
every job), so a draft PR gets no comprehensive gate. Rule: read the
workflow's draft guard at setup. When the final push exists to run the full
gate, open the PR as ready, and record that as a ruling in the ledger.

## Gate arguments as arrays, again

A light-gate script stored `just -f <path>` in one variable and passed it to
`testlock` as a single word. Every test step exited 127 (command not found),
so the red gate was void. Rule: build commands as arrays
(`J=(just -f "$PWD/Justfile")`, `testlock "${J[@]}" test-file …`), and check a
red gate's exit codes before reading it as test failures. See "A gate script
passes arguments as arrays" above.

## A CI red can be a pre-existing flake

Rule: before fixing forward, check whether the failing test's file is in the
diff and whether the test has failed on main. If neither, rerun, and file a
hardening ticket.
