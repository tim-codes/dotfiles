---
name: reproduce-web-app
description: Use when asked to clone, reproduce or replicate a feature of a web app the operator is signed in to ("rebuild this editor/dashboard/flow in our stack", "reverse-engineer this web app and build our own"), where the result is original code in the operator's own stack. Pairs with the `rea` skill (what the app runs) and the `build-lead` skill (the multi-lane build).
---

# Reproduce a web app

End-to-end workflow for rebuilding a feature of an existing web app, which
the operator is authorised to inspect (their own signed-in account), as
**original code in the operator's own stack**: gather evidence, check for an
open-source foundation, write a blueprint, build in lanes, compare with the
original, record deviations.

**Status: proven on one target.** Run once, 2026-11-16: a hosted rich-text
email-template editor reproduced as a standalone Vite SPA. How well the
comparison step went is recorded in that run's README ("how it compares"),
not asserted here. Treat everything below as one run's method.

Pairs with `rea` (the web route: what the app runs; passive commands only)
and `build-lead` (merging lanes; referenced, not restated). Procedure
detail: [references/behaviour-ledger.md](references/behaviour-ledger.md),
[references/blueprint-and-lanes.md](references/blueprint-and-lanes.md),
[references/lessons.md](references/lessons.md).

## Ground rules (state them to the operator at the start)

- Reproduce behaviour and appearance in original code. Never copy the
  target's source, bundle text or assets into deliverables; record
  identifiers, labels, measurements and design tokens.
- Do not read or record cookies, storage, tokens, headers or account data.
  The operator's signed-in session is theirs.
- Out of scope: features that are services rather than components (AI,
  realtime collaboration, publishing, embeds needing third parties). Their
  entry points are omitted, not stubbed.

## Before starting, tell the operator

- You need a debugging Chrome on a separate profile for the `rea` web route
  (command in the `rea` skill; the operator launches it).
- A scratch object they nominate will be **edited and restored**; edits sync
  live to any of their own tabs showing it.
- Nothing is published, sent, deleted, renamed or created in the original.

## Workflow

0. **Scope first; ask, do not infer.** Agree the target, where the
   reproduction lives (a new empty local repo, an empty root commit on
   `main`, all work on a branch, no remote unless asked), and the stack and
   conventions. Conventions come from the convention skills **read first-hand
   by the agent doing the work**, never from a summary (a lead's inferred
   stack and a second-hand library version were both wrong in the run).
1. **Three evidence streams in parallel**, separate agents, each writing a
   file:
   - **Behaviour ledger**: live inspection through the operator's signed-in
     browser, checklist first, every claim tagged OBSERVED / INFERRED /
     UNKNOWN. Mutation rules and warnings in the reference.
   - **Bundle evidence**: the `rea` web route. Confirms which open-source
     package the app is built on and lists hosted-only additions the UI
     cannot show (node types, attributes, menus, shortcuts, libraries).
   - **Open-source foundation check**: does the vendor publish the feature
     as a package (`npm view`, their GitHub org)? Assess licence, API
     surface, shipped UI versus hosted additions, customisation points,
     risks, version to pin. Also survey the destination codebase read-only
     for prior work on the same feature. In the run this one early check
     turned "rebuild an editor" into "add the hosted chrome on top of the
     vendor's own headless package": the most valuable finding.
2. **Commit the ledgers** into the reproduction repo (e.g. `docs/rea/`).
   They are the spec implementers build from without access to the original.
3. **Scaffold early**, in parallel with evidence: tooling, conventions, a
   minimal working instance of the foundation package, the repo's check and
   full gate, a browser check. Read tool docs from installed versions; let
   the toolchain's real compatibility decide versions.
4. **Blueprint** by a read-only design agent on the most capable model, from
   both ledgers, the installed package's types and dist, and the convention
   skills. Contents and the open-questions rule:
   [references/blueprint-and-lanes.md](references/blueprint-and-lanes.md).
   Save it in the repo. The lead answers open questions with **recorded
   rulings** so the build does not wait, and reports them for the operator
   to overturn.
5. **Build with `build-lead`**: foundation lane first (most capable model;
   verified in a real browser and by the full gate; a stub for every slot),
   then one worktree and one implementer per lane, launched together, each
   with a short lane prompt plus a common brief file. Model per lane by risk.
   Lanes report DONE_WITH_CONCERNS with deviations, NEEDS_LEAD items and
   "what integration should check". The lead merges `--no-ff` in any order
   the stubs allow, runs the fast check on the merged tree, and relays
   cross-lane hazards to lanes still running.
6. **Integration and comparison lane**: one agent on the merged branch
   (frozen-file rule lifted). Collected integration points first, then a
   section-by-section comparison against the ledger in a browser at the
   ledger's viewport, with read-only looks at the original for appearance.
   Fix with regression tests; record large items as known gaps rather than
   starting them; README gets "how it compares" (reproduced / deliberate
   deviations / known gaps / not verifiable); full gate once at the end.
7. **Final report** to the operator: what landed, gate verdicts, deviations
   and gaps, rulings made, what to look at first. Offer further passes
   (whole-branch review, UX pass) rather than running them unasked.

## Rules from the run (reasons in `references/lessons.md`)

- Parallel lanes never share one browser automation context: each gets its
  own dev-server port **and** creates and addresses its own page explicitly.
- Lane verification against stubs proves less than it looks: collect each
  lane's "integration should check" list into the integration brief.
- Commit-trailer attribution in a subagent follows that subagent's own
  harness reminder, not the brief; check trailers when merging.
- The `rea` rules do not travel into subagents: restate them in the brief.

## Roles and models (as used)

| Role | Model |
|---|---|
| Behaviour-ledger agent (browser) | capable mid-tier |
| Bundle-evidence agent (`rea`) | capable mid-tier |
| Foundation-check research | mid-tier |
| Blueprint (read-only design agent) | most capable |
| Foundation lane | most capable (everything depends on its interfaces) |
| Feature lanes | by risk: mid-tier for mechanical, most capable for interface-heavy |
| Integration and comparison lane | most capable |

## When not to use

- No authorised access to the original (not the operator's own account or
  explicit permission).
- The goal is a pixel-for-pixel or asset-level copy rather than a functional
  reproduction in original code. This skill declines to copy assets or source.
- A single small component that needs no lanes: do steps 0 to 2, then build
  directly.
