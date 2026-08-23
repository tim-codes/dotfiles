---
name: mantine-docs
description: Look up Mantine UI API, props, components, hooks or theming — which of the three Mantine lookup paths (MCP server, vendored skills, llms.txt index) to use and in what order. Use whenever writing or reviewing Mantine code, choosing a component, checking a prop or hook signature, or debugging a Mantine styling/theming problem, and before answering any Mantine question from memory.
---

# Mantine lookups

Mantine is the standard UI framework for Exxo frontends and for personal
projects. It ships fast and breaks API surface between majors, so **never
answer a Mantine question from memory** — every path below is cheap.

## Order

1. **The `mantine` MCP server** — first choice, and the only path that is
   never stale. Registered in every Claude context by `scripts/claude-sync`
   (`files/claude/mcp.shared.json`), so it is available outside this repo too.

   | Tool | For |
   |---|---|
   | `list_items` | what components/hooks exist |
   | `get_item_doc` | a component's documentation |
   | `get_item_props` | exact prop names, types, defaults |
   | `search_docs` | free-text across the docs |

   `get_item_props` is the one that settles arguments. Reach for it before
   writing any prop you have not verified in this session.

2. **The vendored `mantine-*` skills** — `mantine-form`, `mantine-combobox`,
   `mantine-custom-components`. Upstream's own deep guidance on the three
   areas where the API is easiest to get wrong. Load the matching one when
   the work is squarely in its area; the MCP server answers *what the API
   is*, these answer *how it is meant to be used*.

3. **`references/llms.txt`** — the compact index of every documentation page
   with its URL. Use it to find the right page to fetch when the MCP server
   is unavailable (no network for `npx`, server not yet installed) or when
   you want the page itself rather than an extracted answer.

`llms-full.txt` (~1.8MB, the whole documentation set in one file) is
deliberately **not** vendored — it is rewritten every release and duplicates
what the MCP server already answers. Fetch it from
`https://mantine.dev/llms-full.txt` in the rare case a bulk offline read is
genuinely what is wanted.

## Project conventions come first

This skill covers the framework, not how a given codebase uses it. Exxo repos
carry their own opinionated guidance — the `styling` skill (Mantine props >
Vanilla Extract > inline styles) and per-repo skills under
`.claude/vendor/skills/`. Where those disagree with upstream's defaults, the
project wins.

## Provenance

The `mantine-*` skill directories are vendored **byte-for-byte** from
[`mantinedev/skills`](https://github.com/mantinedev/skills) — do not edit
them, local edits are destroyed by the next refresh and make it impossible to
see what upstream changed. Our own framing goes here, in this file.

- Pin and file list: `files/claude/vendor/mantine.lock.json`
- Refresh: `scripts/vendor-mantine` (`--check` reports whether the pin is behind)

The same upstream is vendored independently into `Exxo-Labs/skills` for the
work context. Both pull from `mantinedev/skills`, never from each other, so
the copies cannot chain-drift.
