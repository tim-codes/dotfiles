---
name: ux-designer
description: 'Experimental: Use when Tim says /ux-designer, asks for a design critique or redesign of a UI (running web app, screen, flow, navigation), or asks for design-only work such as architecture diagrams or layout variants drawn from a reference board and repo or SharePoint material.'
---

# ux-designer

Experimental; available in the personal and exxo contexts. This session is
the designer: it runs the whole job itself, in place. The skill never
launches, briefs or messages another session, tmux window or peer.

## Inputs

`/ux-designer <scope> [references]`

- **Scope** (required): what to design or fix, in a sentence or two.
- **References** (optional): a target URL, repo paths, a reference board,
  SharePoint folders, Figma links, screenshots. A target URL is optional;
  design-only work (for example architecture diagrams with variants) has
  none. If the scope is unclear, ask Tim one question before starting.

Record the scope and references in the task tracker.

## Setup

1. Scratch files live in this session's scratchpad directory (named in the
   system prompt), never `${TMPDIR}` or `/tmp`: the Artifact tool publishes
   only from the scratchpad. Screenshots, hand-off specs and canvas sources
   go there, uncommitted.
2. `Artifact` with `action: "quickstart"` and `intent: "design"` shows
   whether the Design canvas type exists. If it does not, tell Tim; there is
   no fallback canvas.
3. Check tools lazily, with `ToolSearch`: Playwright only when there is a
   target URL; the Microsoft 365 connector only when SharePoint is a source.
   A tool that needs a sign-in is a gap: tell Tim and carry on without it.
   Never start a sign-in or dialog unannounced.

## 1. Critique

Gather sources, read-only:

- **Running UI:** browse the target with Playwright (navigate, read, hover,
  open menus, switch tabs; never submit a form or take any create, edit,
  delete, send or settings action; if a click could change data, describe
  the state instead). It may be Tim's live instance. Use
  `exxo-common:agent-chrome-screenshots` only for a signed-in page Playwright
  cannot reach.
- **Repo:** read the UI code and config for the component library, theme,
  tokens and conventions, so directions are buildable in that stack. Load a
  matching stack skill (for example `mantine-docs`).
- **SharePoint:** search and read through the Microsoft 365 connector,
  read-only; never upload, move, rename or edit.
- **Reference boards and links:** read what Tim points at.

Then give Tim a concise critique: what works, problems ranked by impact,
what is out of scope. Use `design:design-critique` and
`design:accessibility-review` for UI. Long detail goes in a scratchpad file.

## 2. Draft directions

One Claude Design canvas per scope, from the Design type found in Setup,
titled for the scope. One artboard per direction; when the scope is tight,
one buildable artboard and no options. For architecture or other diagrams,
draw the variants on the canvas the same way, grounded in the sources.

- Write a hand-off spec per direction following `design:design-handoff`
  (layout, tokens, components, states, responsive behaviour, edge cases) into
  the scratchpad.
- Use `design:ux-copy` for proposed wording and `design:design-system` when
  a direction adds or changes a pattern.
- Give Tim the canvas link and a one-paragraph comparison.

## 3. Tim chooses

Tim picks by commenting on the canvas (read with `ArtifactComments`) or by
telling you. Never choose for him. Approved artboards stay as they are; a
changed direction goes on new artboards, as the canvas keeps no history.

## 4. Build and review (optional)

Only when Tim wants the chosen direction built. If this session is also the
one working in the app, prototype it yourself, following the repo's
conventions (branch, preview such as `just preview`, tests, commit style).
Then review your own build once against the artboard and spec with
`design:design-critique` and `design:accessibility-review`, fix what it
finds, and give Tim the preview URL and commit SHA. Another round starts only
on Tim's word.

## 5. Wrap-up

Only when Tim says drafting is final. Summarise: the scope, the chosen
direction, what was built, what is open, with links. If Tim wants the final
artboards in Figma, see Figma below.

## Figma

General guidance: draft on the Claude Design canvas; Figma is not needed
until later. That is a default, not a gate. When Tim explicitly asks for
any Figma or FigJam task, at any point, do it now; never decline it or defer
it to wrap-up. That includes creating a new file when he asks for one
(`create_new_file`; ask for the name and team if he did not give them).

- Follow `exxo-common:claude-design-workflow` (section 3, Record in Figma;
  there is no canvas-to-Figma export) and `exxo-common:working-with-figma`.
  Load Figma's own skills before the matching tools (`figma-use` before
  `use_figma`, `figma-generate-diagram` before `generate_diagram`,
  `figma-design-to-code` before `get_design_context`); without the Figma
  plugin, read them with `get_figma_skill`.
- Call `create_session` for the file first, and `search_design_system` to
  reuse its components, variables and styles.
- Guards: write only to a file Tim named or asked you to create, and never to
  a client snapshot (a copy of a client's file kept for reference), even when
  Tim's file links to one. If the named file looks like one, stop and ask.

## Rules

- Generic: the scope, references and stack come from Tim and the repo.
- Read-only on the target app and on every source (repo, SharePoint, boards).
  App code is written only in step 4, in a repo Tim asked you to build in.
- Never create, message or close another session or window; if Tim wants a
  separate designer peer, that is a different skill.
- Experimental: not prescribed in product repos or the shared roster until
  Tim promotes it.
