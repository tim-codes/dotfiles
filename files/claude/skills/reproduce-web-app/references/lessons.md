# Lessons

From the single run on 2026-11-16 (hosted rich-text email-template editor
reproduced as a Vite SPA). Each entry is the rule and what it cost.

## Ask for the stack; do not infer it (2026-11-16)
The lead inferred the stack from the product repo the feature was destined
for. The operator corrected it: the prototype uses the organisation's
standard SPA stack and none of the destination product's UI libraries.
Rule: confirm stack and conventions at step 0.

## Conventions are read first-hand (2026-11-16)
A second-hand summary gave the wrong major version of the UI library; it was
caught only because an implementer read the convention skills themselves.
Rule: the agent doing the work reads the convention skills; never pass a
summary as a substitute.

## Check for a vendor package before designing (2026-11-16)
One `npm view` early on showed the vendor publishes the feature headlessly,
which changed the whole plan. Rule: the foundation check runs in parallel
with the first evidence, before any design.

## Read the package's dist, not its docs (2026-11-16)
The blueprint agent found, only in dist: a configuration option that
disabled a feature silently; an overlay outside the focus scope that cleared
the selection; an add-on package with unwanted dependencies; custom nodes
needing a base class or export dropped them. Rule: the blueprint's findings
section comes from installed code.

## The live product mutates the operator's view (2026-11-16)
Edits synced live to the operator's own open tab. Rule: warn before starting,
edit one nominated scratch object, restore and verify.

## Typing can create persistent entities (2026-11-16)
Typing a new variable token auto-created an entity that had to be removed
through a confirm dialog. Rule: avoid creating tokens; use existing ones.

## Menu items can open native pickers (2026-11-16)
An "Image" item probably opened a system file picker in the operator's
browser. Rule: never trigger upload-like items; observe the menu only.

## The browser tool's privacy filter blocks dumps (2026-11-16)
Some DOM dumps were refused. Rule: use targeted computed-style and
bounding-rectangle probes.

## Overlays and form submission interact across lanes (2026-11-16)
A package form submitted on any outside mousedown, so another lane's popover
had to render inside the form; a lane's panel-mounting expectations had to be
passed to the inspector lane. Rule: the lead relays cross-lane hazards to
lanes still running.

## Lanes must not share a browser context (2026-11-16)
Two lanes on one Playwright browser switched the "current tab" under each
other and produced misleading results until each used its own tab or
context. Rule: own port **and** own explicitly created and addressed page.

## Stub verification proves less than it looks (2026-11-16)
Lanes verified against stubs of the other lanes' slots. Rule: each lane
reports "what integration should check"; the lead collects them into the
integration brief.

## Trailer attribution follows the subagent's harness (2026-11-16)
Commit-trailer lines in a subagent follow its own harness reminder, not the
brief. Rule: check trailers when merging; do not rely on the brief.

## Open questions get rulings, not waits (2026-11-16)
The blueprint's questions were answered by the lead with recorded rulings so
lanes could start, then reported to the operator to overturn. Rule: decide,
record, report.

## Comparison outcome
How the comparison step turned out is recorded in the run's README ("how it
compares"), not here; this skill makes no claim about its quality.
