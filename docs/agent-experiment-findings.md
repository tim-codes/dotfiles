# Agent experiment findings

Date: 2026-08-23

## Probe scope and method

The probe was read-only. It inspected documented locations, path existence,
directory entry names, application bundle identifiers, archive member names,
and non-secret binary strings. It did not open live Codex/Claude/Air settings,
authentication files, histories, MCP documents, plugin state, or credential
values.

Reproduce the experiment-level report from the dotfiles repository:

```sh
scripts/agent-experiment inspect --adapter codex-air --profile exxo-h2gc-portal
```

Reproduce the narrow Air bundle check:

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' ~/Applications/Air.app/Contents/Info.plist
find ~/Applications/Air.app/Contents/app/code-cache -name '*agent.codex*.jar' -print
unzip -l ~/Applications/Air.app/Contents/app/code-cache/4cb12c873bd3c563e027f00893d0a77d00f0dbc20067c459290905121741b6b3/fleet.plugins.ai.agent.codex.workspace.jar
```

The final archive name is version-specific; select the current
`fleet.plugins.ai.agent.codex.workspace.jar` reported by `find` when repeating
the probe. Searching that archive's non-secret strings for `CODEX_HOME`,
`AGENTS.md`, `SKILL.md`, and `.agents/skills` is safe; report matches by name,
not surrounding configuration values.

## Codex result: supported and documented

Official OpenAI documentation establishes the instruction chain:

1. global `AGENTS.override.md`, otherwise `AGENTS.md`, under `CODEX_HOME`
   (default `~/.codex`);
2. one instruction file per directory from project root down to the current
   working directory, preferring `AGENTS.override.md`, then `AGENTS.md`, then
   configured fallback names; and
3. root-to-current-directory merge order, with closer guidance later and
   therefore higher precedence.

Source: [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

Official documentation also establishes Codex local skill discovery at
repository `.agents/skills` directories from the current directory up to the
repository root, user `$HOME/.agents/skills`, admin `/etc/codex/skills`, and
bundled system skills. A skill directory requires `SKILL.md`; optional
`agents/openai.yaml` supplies OpenAI-specific metadata. Duplicate skill names
are not merged and can both appear, which reinforces this experiment's stricter
collision-key rejection.

Source: [Build skills](https://learn.chatgpt.com/docs/build-skills).

Observed locally during this probe:

- `CODEX_HOME` was not overridden, so its documented default is
  `/Users/tim/.codex`;
- `/Users/tim/.agents/skills` was absent;
- the dotfiles experiment worktree had no repository `.agents/skills`; and
- `/etc/codex/skills` was absent.

What worked: deterministic `AGENTS.md` rendering can be supplied explicitly to
Codex, and the rendered packet correctly tells Codex to read h2gc's existing
root `AGENTS.md` before planning. What was deliberately not attempted: writing
the packet to `~/.codex`, `$HOME/.agents/skills`, or the h2gc repository.

## Air result: Codex runtime present, user discovery unverified

Observed locally:

- Air is installed at `/Users/tim/Applications/Air.app` with bundle identifier
  `com.jetbrains.air`;
- Air has existing application-data roots at
  `/Users/tim/Library/Application Support/JetBrains/Air`,
  `/Users/tim/Library/Caches/JetBrains/Air`, and
  `/Users/tim/Library/Logs/JetBrains/Air`; all are protected staging targets;
- its application bundle contains a Codex workspace integration archive named
  `fleet.plugins.ai.agent.codex.workspace.jar`;
- archive class names show Codex CLI/ACP distribution, runtime, configuration,
  and session-provider integration;
- non-secret archive strings include `CODEX_HOME`, `~/.codex/config.toml`, and
  `cwd/.codex/config.toml`; and
- the same string probe produced no explicit `AGENTS.md`, `SKILL.md`, or
  `.agents/skills` discovery root.

Inference: Air has a concrete Codex runtime adapter and is aware of Codex
configuration, but the bundle evidence does not establish whether Air preserves
Codex CLI instruction/skill discovery unchanged, overrides `CODEX_HOME`, or
adds an Air-specific user installation root. No prompt-level Air run was made
as part of this repository-only implementation, so Air precedence remains
unknown.

What worked: the staged bundle remains usable as an explicit, inspectable
context attachment. What did not work: the static probe did not prove any
Air-recognised user-level skill or global-instruction installation location.

## Pilot routing and security result

`validate --profile exxo-h2gc-portal` confirmed the existing h2gc instruction
files, pinned submodule skill paths, `Justfile`, and `agent/run` entry point all
exist. The rendered packet:

- routes planning to the existing h2gc `AGENTS.md`/OpenSpec instructions;
- names `just skills-check` as the pinned-skill staleness check;
- preserves `agent/run -- <command>` for manual platform operations;
- leaves the application's environment flow with `just install` and existing
  recipes; and
- does not include `agent.env`, resolved values, MCP values, provider
  permissions, private plugin contents, or authentication state.

## Go/no-go recommendation

Go for continued render-only and disposable staging experiments. No-go for a
live Codex or Air installation from this work.

Codex's documented roots are sufficient to design a future adapter, but using
them would alter existing live configuration and therefore requires a separate,
explicitly approved promotion plan. Air's actual instruction/skill precedence
is still unknown. Promotion requires a reproducible Air prompt-level probe that
reports loaded instruction sources and skill availability, plus collision,
rollback, credential-boundary, and ownership review. Until that evidence
exists, attach the staged bundle explicitly and do not guess an Air path.
