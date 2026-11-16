# Behaviour ledger

The ledger is the spec implementers build from without access to the
original. One agent writes it, incrementally, through the operator's
signed-in browser (in the run: the Claude-in-Chrome extension, in a **new
tab**; leave the operator's tabs alone).

## Write the checklist first

Put it at the top of the ledger and finish with a status table keyed to it.
Generic starting set (trim or extend per target):

- A. Layout and chrome: regions with measured rectangles, scroller, fixed or
  floating parts, surfaces, top bar, menus, side rails, alternate views.
- B. Field groups (headers, forms): labels, order, placeholders, reveal rules.
- C. The editing model: editable root, typography, placeholders, hover
  affordances, selection, drag and drop, keyboard, shortcuts, undo/redo.
- D. Every menu, in order, with every item and its group.
- E. Every panel per object type: each control's label, type, default,
  placeholder and units.
- F. Design tokens via computed styles (colours, radii, heights, fonts) in a
  table.
- G. Data-model clues from the DOM (attributes, classes, node names).
- H. Empty states, toasts, autosave, shortcut help, and anything else a user
  would notice.

## Tagging

Every claim carries one tag:

- **OBSERVED**: seen directly; say how (screenshot, accessibility tree,
  `getBoundingClientRect`, `getComputedStyle`). State the viewport once.
- **INFERRED**: reasoned from observations; give the basis.
- **UNKNOWN**: not determined; say what was tried.

Write incrementally so a cut-off session loses nothing. End with the
checklist status table and an **unknowns** section the blueprint can plan
around.

## Starting-state record

Before touching anything, record the scratch object's state: every field,
the body in order, variables and their fallbacks, every setting at its
default. It is the restoration target and also documents defaults.

## Mutation rules

- Edit only inside the one scratch object the operator nominated.
- Restore afterwards and **verify the restoration in the DOM**, against the
  starting-state record.
- Never publish, send, delete, rename or create; never trigger native
  dialogs or file pickers.
- Do not read cookies, storage, tokens, headers or account data. Project
  fields out of page dumps; keep nothing account-specific in the ledger.
- Tell the operator up front that temporary edits will be visible.

## Warnings (each happened in the run)

- A menu item ("Image") probably opened a system file picker in the
  operator's browser. Treat any upload-like item as observe-only.
- Typing a new variable token auto-created a persistent entity that then had
  to be deleted through a confirm dialog. Typing into a field can create
  records: use existing entities, or avoid new tokens.
- The product synced edits live to the operator's own open tab, so they saw
  the changes. Hence the up-front notice.
- The browser tool's privacy filter blocked some DOM dumps. Fall back to
  targeted `getComputedStyle` and `getBoundingClientRect` probes.
