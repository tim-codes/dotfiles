# Blueprint and lanes

## Blueprint (read-only design agent, most capable model)

Inputs: both ledgers, the installed package's types and **dist** (not its
docs), the convention skills. Saved in the repo (e.g. `docs/build-blueprint.md`).

Required contents:

1. **Findings that change the plan**, each with evidence and the fix. In the
   run, reading the package's dist found: a scaffold option that silently
   disabled a whole feature; that any overlay rendered outside the package's
   focus scope cleared the selection; that an obvious add-on package dragged
   in unwanted dependencies; that custom nodes had to extend a package base
   class or export silently dropped them.
2. **What to assume** for ledger items tagged INFERRED or UNKNOWN that the
   build depends on.
3. Architecture and state model.
4. **Exact cross-lane interfaces with signatures.**
5. A **foundation lane**, then 3 to 5 **parallel lanes** with disjoint file
   ownership.
6. **Merge rules**: dependencies added only in the foundation; composition
   root, extension list, store and types frozen after it; lanes fill stub
   files keeping names and signatures; lockfile touched only by the lead;
   README edited only by the foundation.
7. An **integration checklist keyed to the ledger's sections**.
8. A **deferred list** (out of scope, marginal, unknown).
9. **Open questions.** The lead answers each with a recorded ruling in the
   blueprint ("Build lead decisions") so lanes are not blocked, and reports
   them to the operator, who may overturn them.

## Foundation lane

Lands first, on the most capable model. Shell layout, design tokens, store,
editor wiring, shared controls, test utilities, and a **stub for every slot**
so each lane compiles on its own. Verified in a real browser and by the full
gate before lanes launch.

## Common lane brief skeleton

One file shared by all lanes, plus a short per-lane prompt (lane section,
port, model). The common file restates what does not travel into a fresh
context:

- Project in two sentences; what the foundation already provides.
- **Source of truth order**: blueprint sections, then the ledger headings the
  lane cites, then bundle evidence, then the foundation code as it is (code
  wins; list known foundation deviations).
- **Frozen files** and the NEEDS_LEAD route for needing one changed; the one
  exception for a blocking foundation bug (separate labelled commit).
- **Conventions**: absolute paths of the convention skills, read first-hand;
  how to look up library facts (installed types and dist, not memory).
- Out-of-scope features get no entry points.
- **Environment mechanics**: install per worktree; use the repo's `just`
  recipes; wrap heavy runs in the machine test lock; run only own tests while
  iterating, the full gate once at the end.
- **Browser verification**: each lane has its own port (strict), its own
  page created and addressed explicitly, never another lane's.
- **Git**: own branch only, explicit staging, no stash, no push, no merge;
  commit trailer lines.
- Working method: tests first for logic; verify against state and DOM where
  other lanes' slots are still stubs; fidelity to the ledger.
- **Report contract** (under ~50 lines): DONE / DONE_WITH_CONCERNS / BLOCKED;
  commits; gate tail; each acceptance criterion as verified in browser /
  by test only / not verifiable until integration / not met; deviations;
  NEEDS_LEAD; foundation bugs fixed; **what integration should check**.

## Merging

Lead merges with `--no-ff`, in any order the stubs allow (the run chose the
order so each merge showed more working behaviour), runs the fast check on
the merged tree, and relays cross-lane hazards to lanes still running. Never
touch the integration worktree while a gate runs in it (`build-lead`).

## Integration brief skeleton

- Frozen-file rule lifted; one agent on the merged branch.
- First: the collected "integration should check" lists from every lane and
  every relayed hazard.
- Then: section-by-section comparison against the ledger, same lettering as
  the checklist, in a browser at the ledger's viewport; read-only looks at
  the original for appearance only.
- Fix what is small, with regression tests; record large items as known gaps.
- Restoration and persistence checks (reload keeps state).
- README "how it compares": reproduced / deliberate deviations / known gaps /
  not verifiable.
- Full gate once, at the end.
