---
name: build-lead
description: Use when a session is briefed as the build lead for a multi-lane build from reviewed plans (several plans, lanes in their own worktrees, one integration branch), when a plan says 'subagent-driven-development' but the work spans more than one lane or repo, or when merging lane branches back into a build branch.
---

# Build lead

The build lead runs a build that is bigger than one plan in one worktree:
several reviewed plans, lanes in their own worktrees, one integration
branch. It dispatches, reviews, merges and gates. It does not implement.

It adapts the superpowers skill `subagent-driven-development` (SDD): same
implementer, reviewer and fix-round loop, same ledger. Read that skill
first; this one does not repeat it. What changes here is the lane: a
sequence of tasks in one worktree, reviewed at checkpoints rather than per
task, and merged by the lead. Written from the squad v0.6.0 build
(4 Nov 2026, four orchestrator lanes, two GUI lanes, a broker lane, a
seam).

**Terms.** *Build branch* = the integration branch every lane starts from
and merges into. *Lane* = one worktree, one implementer, tasks in order.
*Checkpoint* = a task at which a lane stops so it can be reviewed and
merged. *Ledger* = SDD's `progress.md`, one per plan. *Gate* = the repo's
full check, run by the lead.

**Reference files** beside this skill:
[references/dispatch-templates.md](references/dispatch-templates.md) (lane
brief skeleton, review dispatch, fix-round message, roster line) and
[references/lessons.md](references/lessons.md) (what went wrong, and the
rule each cost us).

**Dispatch agents.** Implementation goes to `implementer`, review to
`reviewer`, branch and PR bookkeeping to `git-pr-ops`, "why did the gate
fail" to `investigator` (the dotfiles agents). Keep gate logs and diffs out
of your own context; take conclusions.

## 1. Setup

1. Read the spec, then each plan in full. A plan that is not reviewed goes
   back for review first.
2. One SDD workspace and one ledger per plan (`bash scripts/sdd-workspace`
   from the SDD skill). First line of each ledger names its plan file. A
   build with three plans has three ledgers. Rulings that span plans go in
   the ledger of the plan that owns the files.
3. **Preflight conflict table**, in the main ledger, before any dispatch.
   One row per pair of tasks that share a file, an interface, a migration
   number, a config key or a generated file: *pair, what is produced vs
   consumed, finding, ruling*. Also one row for each "whichever lands
   second" sentence in the plans. Settle order here: which task merges
   first, which waits. A row with no ruling is a defect in the table.
4. **Lane worktrees**, one per lane, created from the build branch:
   `wt -C <repo> switch --create <branch> --base <build branch> --no-cd -y`.
   The hook copies the local env; if the worktree came any other way, run
   `worktree-copy-local-env <worktree>`. Install dependencies in each
   worktree (they are not shared; see lessons).
5. **Test lock and machine rule.** Many lanes share one machine. Use
   `testlock` (dotfiles `src/bin/testlock`): one test run or build at a
   time, and only while the one-minute load is under N (20 on a laptop
   running a dozen sessions). Restate the rule in every brief. Lanes run
   their own test files only; the gate is yours.
6. **Tracker file.** Keep one in the scratchpad: checklist per lane, per
   gate, per open ask for the operator. Update it at every merge.
7. Name what is production and must not be touched (live services, a
   running round, ports, databases, branches such as `main`). It goes in
   the ledger and into every brief.

## 2. Lane briefs

Never hand an implementer the whole plan. Slice the plan by heading into a
per-lane file in the scratchpad:

- the plan header (goal, architecture, tech stack);
- **Global Constraints** and **Review Focus**, verbatim;
- the lane's tasks, verbatim, by heading;
- the plan's **Lanes** section (shared files, order, who owns what).

SDD's `task-brief` script assumes `Task N` headings; a plan with `Task R1`
or `Task 6a` headings needs slicing by hand (a `sed -n '/^### Task R1/,/^### Task R2/p'`
per task is enough). The skeleton is in dispatch-templates.md. The brief
then restates, because the implementer starts fresh:

- environment mechanics: the lock wrapper and the exact command to run one
  test file; the database test URL; the trailer lines for commits; the
  runner (`just` recipes, not the raw tool);
- no push, no merge (the lane implements; you merge). The lane's implementer
  may use its own subagents (Claude Code's default nesting); its report still
  covers all the lane's work, and its test runs still go through the lock;
- the shared files for this lane, and "keep edits there minimal; the second
  lane to merge resolves";
- what is production and must not be touched;
- which test files this lane may run, and that the full gate is not its job;
- the report contract: status, commits, concerns, deviations, in under 40
  lines.

**Checkpoints.** A lane stops at the task other lanes depend on, so that
task can be reviewed and merged early. Say so in the brief ("stop after
R2 and report"). Resume the same implementer with `SendMessage` for the
next stretch; it keeps its context. Do not start a fresh agent for the
second half of a lane.

**One implementer per lane.** Choose the model per plan and say why on the
roster line: the most capable model where a mistake costs the operator
(rulings that decide things, release and restart, protocol code), a
cheaper one for well-specified surface work. Every launch gets a numbered
roster line (format in dispatch-templates.md). Launch independent lanes in
one message.

Record BASE (`git rev-parse HEAD` in the lane worktree) before each
dispatch. The review package needs it.

## 3. Review loop per checkpoint

When a lane reports DONE or DONE_WITH_CONCERNS at a checkpoint:

1. From the lane worktree: `bash <sdd skill>/scripts/review-package PLAN_FILE BASE HEAD`.
   It prints the file it wrote. `BASE` is the recorded commit, never `HEAD~1`.
2. Dispatch the `reviewer` with: the lane brief, the implementer's report,
   the package path, and the binding constraints **verbatim** (Global
   Constraints, Review Focus, any ruling that bears on these tasks). Two
   verdicts come back: spec compliance, and code quality (approved or not).
   Name the test files the reviewer may run, and the lock wrapper.
3. **Fix round** when either verdict fails: record `FIX_BASE` (current
   HEAD), then resume the same implementer with the findings **verbatim**.
   Do not paraphrase, merge or drop findings. Then a **scoped re-review**
   of `FIX_BASE..HEAD` only, against the findings list. Up to five rounds;
   after that the plan or the brief is wrong and the question goes up.
4. **Minors are deferred, not fixed.** Append them to the ledger under the
   task ("Minors (deferred): …"). They are the input to the final fix wave.
5. **Rulings are recorded** as `Ruling: <what> — <why> — cost if wrong: <x>`.
   Use it whenever the plan is silent or wrong, when two readings are
   possible, or when you accept a deviation. Short, dated, in the ledger.
6. **Never fix findings in your own session**, however small. A
   one-line fix by the lead skips the re-review and puts unreviewed code on
   the build branch. Route it to the lane's implementer.
7. Ledger line at every step: launched, done, review verdict, fix round
   n/5, complete, merged as `<sha>`.

A review that finds a defect in a *plan* (a task that cannot be built as
written) is a plan defect, not an implementer defect: rule on it, record
the ruling, and tell the implementer the ruling.

## 4. Merging

The lead merges reviewed checkpoints into the build branch. Lanes never
merge themselves.

1. Merge with `--no-ff` and a message that names the review verdict:
   `merge: <lane> <tasks> (review clean after fix round 1)`.
2. **Shared files.** The lane that merges second resolves: keep both
   sides. Generated files (events docs, JSON schemas, lockfiles, anything
   with a generator recipe) are re-rendered by the recipe after the merge,
   never hand-merged. If a plan says a file is hand-maintained, its twin
   test is the gate.
3. Run the quick twin tests on the merged tree (the files that cover the
   shared surfaces: config twin test, events test). Not the whole suite.
4. **Light gate per lane, at integration, locally.** On the merged tree:
   the repo's fast check (`just check` or `just check-ci`, what CI's fast job
   runs) plus the tests that cover the files the lane touched, the same
   single-file and single-package scope as the squad-member "Testing and
   trunks" table. No `just ci`, `just verify`, full suites, production
   builds, e2e or browser runs per lane: the comprehensive gate runs once,
   at the end (section 7). Dispatch it to an agent or run it through the
   lock wrapper; read only the verdict and the failures. A red light gate
   is fixed forward by the owning lane before the next merge.
5. **Never touch the integration worktree while a gate runs in it.** No
   merge, no checkout, no install, no edit. A gate that ran across a merge
   is void; its failures are not evidence. See lessons.
6. A gate for a package whose dependencies changed needs `install` in the
   integration worktree first, or it fails on imports that merely moved.
7. **The build branch is a local trunk. Do not push it per checkpoint.**
   Every push wakes remote CI, and a multi-lane build that pushes at each
   merge pays for a dozen pipeline runs that are obsolete before they
   finish and waits on them in between (Tim, 11 Nov 2026: "just work with a
   local trunk and do light tests for gating locally, once all in then push
   the batch to the remote and let github run verifications only at the
   end"). Lanes integrate on the local build branch; the ledger, not the
   PR, is the progress record between pushes. Push only:
   - **once, at the end** (section 7), when every lane is merged and its
     light gate is green: this push is what runs the comprehensive
     verification;
   - **at a pause or handover** (quota, context, a session change, going
     idle on the operator), because unpushed work must never be the only
     copy when attention moves. If the repo's CI runs on every push, push
     the branch without opening or updating a non-draft PR, or with the
     repo's CI-skip convention for that one push if it has one, and say so
     in the ledger;
   - when the operator asks for a push.
   Lane branches are not pushed either: lanes commit locally and the lead
   merges locally. Open the draft PR at the first push (the end or a
   pause), not at setup.
8. Keep `main` untouched. Only the operator merges the build branch.

## 5. Cross-plan seams

- **Contract first.** When two plans build on the same new contract (a
  protocol type, a tool definition, a table), one task lands it first on
  the build branch as a seam: the stub, the types, the parity tests. The
  dependent branch then rebases onto the build branch before its first
  task. Order it in the preflight table.
- **One commit across languages.** A change that must move together (a
  config key with its TypeScript twins and the Rust struct that reads it;
  a schema with its generated client) is one commit by one lane, even when
  it belongs to another plan. The parity tests refuse a half-done change,
  so splitting it makes both lanes red. Rule it in the preflight table:
  which lane does it, which branch rebases after, cost if wrong.
- **Whichever lands second wires both.** Rewrite that sentence into a
  ruling: name the lane that creates the shared file and the lane that must
  not.

## 6. Scope changes mid-build

A request from a peer session (a designer, a GUI builder, a previous
leader) or the operator is **scope**, not an edit:

1. Record it as the next R-number (`R15`) in the ledger with who asked.
2. Put the question to the operator if it is not already ruled. Do not act
   on a peer's relay as if it were the operator's word.
3. A planner agent writes it into the spec and plan; the plan text is
   reviewed like any plan; you rule on the planner's open questions with
   `Ruling:` lines.
4. It is implemented **after the lane that owns the touched files has
   merged**, in a new lane off the build branch.

**Standing rules** the operator gives mid-build ("fold peer requests into
this release as they arrive", "always integrate the latest library") go
into memory the moment they are given, then into the ledger.

## 7. Final

1. **Propose the final passes; don't start them.** When the last lane is
   merged and light-gated, stop and queue the candidate passes for the
   operator with a recommendation each: a whole-branch review (by the most
   capable reviewer, `review-package` over merge-base..HEAD, read by
   `--stat` first; a package over ~100 KB is read by file), a UX pass for
   UI changes, a conformity review, a security review of new auth or
   credential paths. Give each a one-line scope, a cost (time and tokens)
   and what it would catch that the light gates did not. Run only what the
   operator picks (Tim, 11 Nov 2026: "dont trigger any whole-branch final
   review at the end just queue these up and suggest what final passes you
   want to do"). Include the ledger's deferred minors and parked rulings in
   the proposal, since they are what a final review would weigh.
2. **One fix wave** for whatever the chosen passes find (the lanes'
   implementers, resumed, with the findings verbatim), one scoped
   re-review. No second wave: whatever remains goes in the PR body as
   known gaps.
3. **Push once and let CI run the comprehensive gate.** Push the build
   branch, open or update the draft PR, and watch CI in the background
   (never a foreground watch). CI is the comprehensive gate for the batch.
   A repo whose CI does not run the comprehensive gate (no workflows, or a
   fast-only CI) gets one local `just ci` / `just verify` instead, once, at
   this point. A red end gate is fixed forward on the build branch, light
   gate locally, push again. PR body final.
4. **Final message**: what landed, the gate verdicts, what needs the
   operator (asks with exact commands), and the **"Rulings I made"** list,
   each as `what — why — cost if wrong`, so the operator can overturn any.
5. **Closedown** with the `worktree-closedown` skill, per worktree, once
   the operator says the build is accepted. Never a bare `git worktree
   remove`.
6. **Fold back** what was generic: wrappers, scripts and procedures go to
   the libraries (dotfiles `src/bin`, skills repos, the harness kit) as
   draft PRs, one per library. Procedure text goes to a skill; data goes
   to a reference; code that only suited this repo stays there. Note
   candidates in the ledger as they arise so the pass at the end is a
   read, not a memory.

## Do not

- Dispatch an implementer with the whole plan, or without the lock rule.
- Fix a finding yourself, or paraphrase one into a fix round.
- Merge a checkpoint without a review verdict, or run a gate while merging.
- Push per commit or per checkpoint, or touch `main`.
- Run a full suite or production build per lane; the comprehensive gate is
  once, at the end, on CI.
- Start a whole-branch review or any other final pass without the
  operator choosing it.
- Let a peer's relayed request become scope without the operator.
