# Agent experiments

This namespace is an additive, vendor-neutral experiment. It describes portable
operational intent and renders reviewable context bundles for explicitly chosen
scratch destinations. It does not install or migrate any live agent setup.

## Safety boundary

The experiment:

- never writes to `~/claude`, `~/.claude`, any `~/.claude-*` context,
  `~/.codex`, `~/.agents`, an Air application-data directory, or
  `files/claude/`;
- never changes a downstream repository, including `h2gc-portal`;
- never reads, renders, logs, copies, or symlinks authentication state,
  histories, plugins, MCP configuration, permission settings, `agent.env`, or
  resolved credential values;
- does not transfer ownership of policy, skills, or executable tooling; and
- performs no automatic installation. `stage` is the only writing operation,
  and it requires an explicit, absolute, existing, empty, unprotected
  destination.

These are hard constraints, not defaults. A future adapter must preserve them
unless a separate, explicitly approved promotion plan changes the contract.

## Source-of-truth model

Portable intent lives under `contract/`: `policy.md` contains provider-neutral
behaviour and `capabilities.yaml` catalogues capability identity, provenance,
audience, delivery, invocation, and collision keys. Profiles select from that
catalogue by allow-list. Adapters translate the selected intent into a format an
agent can consume; they do not become a second source of truth.

The current Claude configuration remains authoritative for Claude. Portable
rules cite their provenance in `files/claude/CLAUDE.md.shared` rather than
copying Claude-specific wrappers, permission syntax, model settings, or mutable
provider configuration. Executable credential behaviour remains owned by
`exxo/agent-tooling`; instructional behaviour remains owned by `exxo/skills`.

## Adapters and profiles

`codex-air` is the first adapter. Codex has documented `AGENTS.md` and local
skill discovery, while Air support remains reference-only until a reproducible
probe establishes an Air-recognised location and precedence. The adapter never
guesses an Air path.

Available profiles:

- `exxo`: portable policy plus the approved Exxo secret-wrapper instruction and
  executable-tool boundary.
- `exxo-h2gc-portal`: `exxo` plus a read-only overlay pointing at the existing
  h2gc portal instructions, pinned skills, `just skills-check`, and `agent/run`.

Use `scripts/agent-experiment inspect --adapter codex-air` for a names-and-paths
only probe, `validate --profile <name>` before rendering, and
`render --profile <name>` for a deterministic bundle on stdout. To materialise
it, create an empty scratch directory yourself and pass its absolute path to
`stage --destination <path>`.

## Cleanup

Remove only the disposable staging directory you explicitly created. A staged
bundle contains no live links or installed state, so cleanup requires no sync,
uninstall, credential purge, or downstream change.

## Promotion criteria

Promotion into live Codex or Air configuration requires a separate approved
plan and all of the following evidence:

1. a reproducible, vendor-documented or directly observed discovery root and
   precedence for the exact host;
2. collision-free capability delivery with a single owner per collision key;
3. proof that no credential-bearing values or broader secret authority enter
   generated artifacts;
4. passing validator, staging-guard, determinism, and redaction tests; and
5. an explicit reconciliation decision for policy drift, ownership, rollback,
   and interaction with existing live configuration.

Until then, staged output is only an explicit prompt/context attachment.
