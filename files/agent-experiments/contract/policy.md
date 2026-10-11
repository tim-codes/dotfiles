# Portable operational policy

This policy contains provider-neutral behaviour only. It grants no credentials,
permissions, installation authority, or authority to override repository-local
instructions.

## Prefer the repository command runner

When a repository supplies a task runner or supported script entry point, list
its available tasks and use that interface instead of bypassing it with an
underlying tool. The wrapper may encode working directories, environment
preparation, credential boundaries, or orchestration that a superficially
equivalent raw command omits.

## Select targets explicitly

Prefer absolute paths and per-command target flags. Avoid workflows that mutate
an ambient selected project, stack, cluster, account, or directory for later
commands to inherit. Each operation should identify its target in the command
that acts on it.

## Respect branch and review boundaries

Do not commit directly to a repository's primary branch unless explicitly
directed. Keep changes reviewable and do not merge or ship without explicit
authority. Repository-local rules may impose a stronger human-review gate and
take precedence. A one-off exception does not become standing permission.

## Treat approval waits as human interaction

A command that appears stalled may be waiting for a visible or out-of-band
human approval. Report that possibility and wait rather than killing it,
retrying repeatedly, or choosing a route that evades the approval. Run
approval-requiring operations separately so the prompt remains attributable.

## Surface environment obstacles

Report missing dependencies, permissions, authentication setup, package-manager
restrictions, and other environment obstacles. Do not silently turn a local
setup issue into an architectural conclusion or broaden access to work around
it. If another already-supported path makes remediation unnecessary, use it
and still record the obstacle.

## Provenance

Portable behaviours were distilled from these durable sections of
`files/claude/CLAUDE.md.shared`:

- `Use the repo's own command runner`
- `Target explicitly; don't rely on ambient state`
- `Git workflow: branch, checkpoint as you go, merge only when directed`
- `Environment/setup obstacles: surface, don't silently work around`
- `A hung-looking command is often waiting on a human approval`

Provider-specific terms, Claude permission syntax, shell wrappers, credential
values, model defaults, and orchestration settings are intentionally excluded.
The cited file remains authoritative for Claude and is not modified by this
experiment.
