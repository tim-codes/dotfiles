# Dispatch templates

Skeletons for the four messages the build lead sends. Fill the braces; cut
nothing that restates an environment rule (a fresh agent has only this
text). Exact values live in the sliced plan, never in the message.

## Lane brief (the file the implementer reads first)

Built by slicing, in this order, into `{scratchpad}/briefs/lane-{X}-{name}.md`:

1. Plan header (title, goal, architecture, tech stack, spec path).
2. `## Global Constraints` verbatim.
3. `## Review Focus` verbatim.
4. The lane's tasks verbatim, by heading, in order.
5. `## Lanes` verbatim (shared files, order constraints, test-file table).

```sh
# one task, by heading (headings that SDD's task-brief cannot parse)
sed -n '/^### Task R1:/,/^### Task R2:/p' PLAN | sed '$d'
```

## Implementer dispatch (the message)

```
You are the implementer for lane {X} ({name}) of {build}. Worktree:
{abs path}. Branch: {lane branch}, off {build branch}. BASE: {sha}.

Read {abs path of lane brief} first: it is your requirements, with the
exact values to use verbatim. Your tasks: {R1, R2}. {One line on where
they fit.} STOP after {R2} and report; do not start {R6}. I will resume
you.

Decided already (not in the brief): {interfaces from other lanes; the
rulings that bear on these tasks, each with its reason}.

Environment, restated:
- One test run or build at a time, host load under {N}. Run every test or
  build through `testlock <command>` from the directory it needs. Check
  `pgrep -fl vitest` first.
- Run only these test files: {list}. The full gate is mine.
- Database test URL: {DATABASE_URL_TEST=...}. Use the repo's runner
  (`just`), not the raw tool.
- Commit each step. Trailers on every commit:
  {Co-Authored-By / Claude-Session lines}
- Do not push, merge, or open a PR. You may use subagents for parts of this
  lane; report all of the lane's work, and run every test through the lock.
- Shared files, keep edits minimal and mechanical: {list}. The second
  lane to merge resolves.
- Production, do not touch: {live service, ports, database, branches}.

Report to {abs path of report file}, under 40 lines: status (DONE,
DONE_WITH_CONCERNS, BLOCKED, NEEDS_CONTEXT), commits (sha + one line),
files, tests run and results, deviations from the plan and why.
```

## Review dispatch

```
Review lane {X} tasks {R1, R2}, commits {BASE}..{HEAD}, in {worktree}.

Brief: {lane brief path}. Implementer's report: {report path}. Review
package: {path printed by review-package}.

Binding constraints, verbatim:
{Global Constraints}
{Review Focus}
{rulings that bear on these tasks}

You may run only: {test files}, through `testlock`. Do not fix anything.
Return two verdicts: (1) spec compliance, per task, with deviations;
(2) code quality, approved or NOT approved. Findings: Critical, Important,
Minor, each with file:line and the smallest fix. Confidence-filtered:
only findings the author would agree are real.
```

## Fix-round message (resume the implementer with `SendMessage`)

```
Fix round {n}/5 for {tasks}. FIX_BASE is {sha}; commit fixes on top.

The reviewer's findings, verbatim:
{paste Critical and Important in full; Minors only if you chose to take them}

Rulings that apply: {Ruling: what — why — cost if wrong}

Same environment rules as before (testlock, your test files only, no
push). Fix every finding or say why not (with evidence). If a finding
shows a defect that is not in your files, say so and stop on that one.
Report: per finding, fixed in {sha} or not fixed and why; tests run.
```

Then: `review-package PLAN FIX_BASE HEAD`, and a scoped re-review message
that lists the findings and asks only "is each addressed, and did the fix
introduce anything".

## Roster line

One per launch, numbered, before the call:

```
{n}. {lane / task} ({agent type}) — {model}[: reason if not the default] — {one-line brief}
```

```
1. lane A items R1,R2 (implementer) — opus: rulings decide items for the operator — stop after R2, reviewed and merged early
2. lane C planning R9 (implementer) — sonnet — surface work, well specified
3. review lane A R1+R2 (reviewer) — sonnet — package review-a6a9552..ea56215.diff, two verdicts
```

Ledger line at launch: `{HH:MMZ} launched: {lane} ({tasks}; {model}) BASE {sha}`.
