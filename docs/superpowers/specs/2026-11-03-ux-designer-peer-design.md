# ux-designer peer session: design

Date: 2026-11-03. Status: draft for Tim's approval. Experimental: a
trial, not yet prescribed anywhere (see Constraints).

## Intent

Tim wants a UX/UI designer working beside his builder session, for
design review and iteration of **any web UI he is building**: a running
app (local dev server, preview build or deployed URL), a given scope
(a screen, a flow, navigation, information density, copy, accessibility,
a redesign), and whatever stack the repo uses. Everything in the agent
and skill is generic: target, scope and stack come from the launch
arguments and the repo, never from hard-coded examples.

**Example use (not a special case):** the squad GUI (Mantine 9,
`~/dev/squad/gui`, live on `localhost:7797`) shows a lot of information;
Tim wants to simplify its presentation and iterate layouts and
navigation.

The designer critiques, proposes and drafts; the builder session
prototypes in the real app; Tim reviews real builds. The designer never
writes app code.

It runs as a **peer Claude session in a sibling tmux window**, not a
subagent. Why:

- it keeps its own memory across rounds (the critique, the canvas, what it
  proposed last time) for as long as Tim keeps the window;
- Tim can talk to it directly in its window;
- designer and builder coordinate session-to-session, which is how the
  estate already runs kickoff peers and squad, and it works well;
- screenshots and design payloads stay out of the builder's context.

## Goals

1. From the builder session, one skill invocation opens the designer in a
   sibling tmux window with a scope, and the designer handshakes back.
2. A round produces: a concise critique of the current UI in scope,
   proposed directions (or one draft when the scope is tight), drafted as
   artboards on a Claude Design canvas, with a handoff spec the builder
   can prototype from.
3. One automatic review pass: after the builder prototypes, the designer
   reviews the build once, the builder iterates once, then Tim reviews.
4. When Tim declares drafting final, a wrap-up stage takes the final
   artboards into Figma.

## Non-goals

- The designer changing app code, tests or repo config.
- Squad integration (broker, `mcp__squad__*`, lanes). This is a plain peer
  pair.
- Shared rollout to other contexts, the global roster, product repos'
  CLAUDE.md or project agents.
- A Figma round-trip during iteration. Figma is wrap-up only.
- Polished visual design in early rounds: drafts are light.

## Anti-goals (a failure even if it "works")

- The designer silently waiting on a Figma or browser sign-in, or raising
  any dialog unannounced.
- Unbounded designer↔builder loops without Tim seeing a build.
- Writing into Figma without Tim naming the target file, or into a client
  snapshot ever.
- Changing data in the target app beyond reading it (it may be Tim's
  running instance).
- Closing or killing Tim's tmux session.

## The flow

### Launch (skill, run in the builder session)

`/ux-designer start <target-url> <scope>` (exact argument shape is the
builder's call; the target and scope are always arguments, the repo is the
builder's cwd unless given):

1. Resolve the builder's own `ListAgents` name and the current tmux
   session (`tmux display-message -p '#S'`).
2. Write a kickoff brief (scratch dir) with frontmatter: `cwd` = the app
   repo, `context` = the builder's context (same context is mandatory:
   native `SendMessage` cannot cross contexts), `model: opus` by default
   (Tim's decision; a lighter model only when Tim asks), `effort`, plus the new
   keys `agent: ux-designer` and `name: ux-designer-<short>` (see
   claude-kickoff changes). Body: scope, app URL, builder's name,
   preview convention, and the round protocol below.
3. `tmux new-window -d -t <session> -n ux-designer -c <cwd>
   "claude-kickoff <brief>"` (member deny overlay kept: harmless, and
   the designer has no merge need); record the window **id**
   (`@N`) and use it, never the name, for later targeting.
4. Wait for the handshake via the native idle/message notification; don't
   poll.

Same permission mode for both sessions (mismatched modes hold
cross-session messages for approval).

### Handshake

The designer's first action: `SendMessage` to the builder, "ux-designer
ready", restating the scope in one or two lines and listing which tools it
can reach (Playwright, Artifact, Figma signed in or not). The builder
replies with anything missing (preview URL if one exists). If a tool needs
a sign-in, the designer says so here and carries on without it; the
builder raises it with Tim.

### Round

1. **Critique.** The designer browses the target in scope read-only with
   Playwright (claude-in-chrome via `agent-chrome-screenshots` only when
   a signed-in page is in scope), takes scratch screenshots (never
   committed), reads the repo's UI code read-only to learn its component
   library, theme and conventions (e.g. `mantine-docs` and
   `frontend/styling` when the repo is Mantine), and sends the builder a
   concise critique.
2. **Draft.** One Claude Design canvas per scope (Design type via
   `Artifact` quickstart; title `<scope>`), one artboard per direction;
   tight scope: one draft artboard and skip options. Plus a
   `design:design-handoff`-style spec per direction. Sends the builder the
   canvas link and spec (large material via a hand-off file).
3. **Choose.** Tim comments on the canvas or talks to either session. The
   designer reads canvas comments itself (`ArtifactComments`).
4. **Prototype.** The builder implements the chosen direction in the real
   GUI, on its preview build (`just preview` convention), and messages the
   designer the preview URL and commit.
5. **One review pass.** The designer reviews the preview build with
   `design:design-critique` and `design:accessibility-review` (the
   claude-design-workflow PR-gate checks), sends feedback once; the
   builder iterates once. Then both stop and Tim reviews. Further rounds
   start only on Tim's word.

The canvas has no version history: approved artboards stay; a changed
direction goes on new artboards.

### Wrap-up (on Tim's "drafting is final")

1. Tim names the Figma target file (that is the explicit write request
   `working-with-figma` requires).
2. The designer rebuilds the final artboards in Figma per
   claude-design-workflow §3 (no canvas→Figma export exists), following
   Figma's own skills.
3. The designer sends the builder the Figma links and a closing summary,
   then the builder (or the skill's `stop` action) closes the designer's
   window by id. Never the session.

## Parts to build

1. **Agent definition** `files/claude/agents/ux-designer.md`: frontmatter
   `name`, `description`, `model: opus` (Tim's decision 2026-11-03, a
   deliberate departure from the estate's sonnet pin for dedicated
   agents: design judgment is the job), and a `tools:` allowlist (the
   parentedit `ui.md` precedent) with no Write/Edit, so "never writes app
   code" is enforced. Bash stays for read-only commands and tmux/kickoff
   is not needed by the designer. Body: the estate Environment block
   (copied from the existing agents), the role, the round protocol, the
   rules above, and pointers (not copies) to `claude-design-workflow`,
   `working-with-figma`, `design:*` skills, and stack-specific skills
   chosen from what the repo uses. No app, repo, port or stack is named in
   the agent or skill except as a labelled example. Writing scratch files (screenshots, hand-off
   files, canvas files under the scratchpad) needs some write path:
   builder's call how (e.g. allow Write but forbid repo paths in the
   body, or Bash-only into the scratchpad).
2. **Skill** `ux-designer` (dotfiles skills): `start <scope>`, `stop`, and
   the builder-side half of the protocol (what to do on the handshake,
   when to message the preview URL, the one-iteration rule, wrap-up).
3. **claude-kickoff changes**: new optional frontmatter keys `agent` →
   `--agent` and `name` → `--name`, with tests in
   `tests/claude-kickoff*.sh`.

4. **Enable the exxo-common plugin in every context** (personal, reserve,
   exxo, exxo-personal, exxo-openrouter) through the repo's plugin/settings
   fragments and `claude-sync` (see the `claude-workstation-setup` skill),
   so `claude-design-workflow`, `working-with-figma` and the other common
   skills are loadable by name. Tim's decision (2026-11-03). Check for
   name collisions with dotfiles-delivered skills first. `exxo-mantine` is
   not part of this: its skills duplicate the dotfiles-vendored `mantine-*`
   skills by name (Claude's call; revisit separately).
5. **Dependency**: the designer relies on the claude-design-workflow
   refresh in Exxo-Labs/skills#79; that PR merges (on Tim's direction)
   before the trial.

## Constraints

- **Experimental, personal-only.** Not in `shared_agents()`, not in the
  global roster in `CLAUDE.md.shared`, no product-repo or squad-repo
  changes (claude-design-workflow `decisions.md` §8). Promote after
  trial. The skill's delivery should likewise be personal-only: check how
  `claude-sync` delivers dotfiles skills per context.
- **Contexts.** Works only in a claude.ai-logged-in Anthropic context
  (personal, exxo): artifacts can't be published from API-key/gateway
  sessions, and Playwright is denied in exxo-openrouter. Builder and
  designer must share a context.
- **MCP.** No `--mcp` profile exists yet (held until after v0.5), so the
  designer launches with the context's default servers, which include
  Playwright and the claude.ai Figma connector. Revisit when profiles land.
- **Operator touchpoints.** No OAuth or dialogs started by the designer;
  report and let the builder raise it.
- **Global rules apply**: secrets referenced, explicit targets, branch
  workflow for this dotfiles change, `claude` binary called as kickoff
  does.

## Decided by Tim

- Peer session in a sibling tmux window, modelled on squad/kickoff
  practice; the skill launches it and the designer handshakes on init.
- Tight scope → skip options, straight to a buildable first draft.
- One automatic self-review/iterate pass before Tim reviews.
- Design and review loop in Claude Design artboards; Figma is a wrap-up
  export stage once drafting is final.
- Disclosure through skills, not product CLAUDE.md; no project/agent
  prescription until trialled.
- Exxo skills plugin enabled in all contexts.
- `model: opus` by default.
- Generic agent and skill: any web UI, any scope, any stack; the squad GUI
  is one example.

## My calls (Claude's; Tim to check)

- Personal-only dotfiles placement rather than a project agent in the
  squad repo (squad is managed by its own sessions).
- Native `SendMessage` + idle notification for comms; no squad broker,
  sockets or send-keys.
- The launch target (read-only) for the critique; the builder's preview
  for the review pass.

## Settled after the builder check (Claude's calls)

- **Contexts for the trial: personal and reserve**, which get dotfiles
  agents and skills by whole-directory symlink. Not exxo (that needs the
  `shared_*()` lists, i.e. promotion). Current targets (e.g. the squad GUI) are personal work, so
  this covers the use case. Reserve has its claude.ai connectors stripped,
  so the Figma wrap-up runs from personal; the designer reports Figma
  unreachable at handshake otherwise.
- **Design type availability**: verified 2026-11-03 in personal
  (quickstart returned the core Design type). If a context lacks it, the
  designer reports at handshake and stops; no HTML-artifact fallback.
- **Tools allowlist**: Read, Grep, Glob, Bash, Skill, SendMessage,
  ListAgents, ToolSearch, Artifact, ArtifactComments, the Playwright
  tools, the Figma connector tools (`mcp__claude_ai_Figma__*`), and Write
  restricted by instruction to the scratchpad. A trial launch that checks
  each tool resolves (including deferred ones) is part of the build; the
  allowlist is adjusted from what it shows. Bash is unrestricted but the
  body forbids repo writes; acceptable for a trial.
- **`--agent` vs the brief's `model:`**: the brief's explicit `--model`
  is intended to win; the trial launch verifies which does, and kickoff
  omits `--model` when the brief has `agent:` and no `model:` if needed.
- **One-iteration rule**: enforced by instructions only (agent body and
  the builder-side skill); no counter for the trial.
- **Names and fallback**: the skill puts the builder's `ListAgents` name
  in the brief and launches the designer with `--name`; the designer's
  handshake carries its own name. If no handshake arrives within a few
  minutes, the builder checks `ListAgents` and the window, and tells Tim
  rather than retrying blindly.

## Left to the builder

Skill argument syntax; brief template wording; how the designer gets a
scratch write path; window naming beyond `ux-designer`; test approach for
the skill (kickoff keys get unit tests); exact hand-off file location.

## Revised 2026-11-06

Tim's decisions after a live run. They override the sections above, which
are left as written.

1. **The skill runs in the session where it is invoked.** That session
   becomes the designer. The skill no longer creates a session, tmux window
   or peer: `start`/`stop`, the handshake, builder/designer messaging, the
   brief template and window ids are gone from it. `scripts/ux-designer-peer`,
   `src/bin/ux-designer-peer` and `tests/ux-designer-peer.sh` stay, unreferenced
   by the skill, for a possible future provisioning skill (which would be a
   separate second skill). The brief template moved next to the script
   (`scripts/ux-designer-peer-brief.md`) so the script still finds it.
2. **The designer procedure lives in SKILL.md:** critique, draft directions,
   Tim chooses, optional build and review, wrap-up. One session does it all;
   when it is also prototyping in the app it does so itself, following repo
   conventions (the "never writes app code" rule existed only for the peer
   split). `design:*` and `exxo-common:*` skills stay as pointers. The agent
   file is reduced to a thin definition (opus, no `tools:` allowlist) that
   loads the skill.
3. **Figma:** drafting happens on a Claude Design canvas and Figma is not
   needed until later, but an explicit Figma or FigJam request from Tim is
   done at once, including `create_new_file` (ask for name and team if not
   given). Guards stay: never write to a file Tim did not name or ask to be
   created, never to a client snapshot. The "builder only" and "wrap-up only"
   rules are removed. The old allowlist omitted `create_new_file`,
   `generate_diagram`, `get_figjam` and `get_design_context`.
4. **Scope is wider than a running web UI:** design-only work such as
   architecture diagrams with variants from a reference board plus repo and
   SharePoint material. A target URL is optional; the input is a scope plus
   references.
5. **Fixes from the 2026-11-06 live run:** scratch files live in the
   session's scratchpad directory (the Artifact tool publishes only from
   there), not `${TMPDIR}/ux-designer-<name>`; source gathering may include
   SharePoint through the Microsoft 365 connector, read-only; the
   "Experimental" framing stays.
