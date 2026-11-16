# Web apps with rea: detailed procedure

Proven once, 2026-11-16, rea 6.9.0 against a signed-in hosted editor
(Next.js/Turbopack, ~133 scripts, ~11 MB). Placeholders: `<scratch>` (an empty
scratch directory outside any repo), `<target-id>`, `<app-url>`. Prefix every
command with `cd <scratch> && npx -y rea-agents@latest` (shown as `rea`).
Add `--format json` and redirect stdout to a file where noted. About 1 s of
each timing is npx start-up.

## 0. Rules (restate in any delegation brief)

Passive commands only; no storage values/fingerprints, cookies or headers;
page output goes to files in `<scratch>`, never into chat, notes or repos;
exported scripts are read, never executed; Python over them runs with `-I`.
Never `rea setup`/`update`.

## 1. Chrome and target

The endpoint must be loopback CDP. Chrome refuses the debugging port on the
default profile, so the operator runs the separate agent profile and signs in
there (setup and safety rules: `agent-chrome-screenshots` skill). Tell the
operator before relying on it; do not launch it for them.

```bash
open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir="$HOME/Library/Application Support/Google/Chrome-Agent"
curl -s -m 3 http://127.0.0.1:9222/json/version        # check
curl -s -X PUT "http://127.0.0.1:9222/json/new?<app-url>"   # optional new tab; leave the operator's tabs alone
rea list-browser-targets http://127.0.0.1:9222 --format json   # ~2 s, ~3 KB
```

On every browser command the endpoint is the first positional argument and the
target id the second. `list-browser-targets` without the endpoint fails with
`VALIDATION_ERROR`.

## 2. Inspect, with script text

```bash
rea inspect-web-page http://127.0.0.1:9222 <target-id> \
  --include-script-sources --observation-ms 1000 --command-timeout-ms 60000 \
  --format json > <scratch>/evidence/inspect-src.json      # ~4 s, ~11 MB
```

- Without `--include-script-sources` the output has script metadata only
  (URL, length, source-map URL), ~0.5 MB with `--include-accessibility-text`
  (DOM node/attribute names, accessibility roles and names, resources,
  console types). It contains signed-in page text and field names: project
  fields with `python3 -I`, never paste.
- There is no summary mode for passive commands; always redirect.
- `--observation-ms` of 1000-1500 was enough for an idle page. Do the
  accessibility pass once and keep the file for offline queries.
- Record the evidence id from the output for tagging.

## 3. Export scripts

```bash
rea export-web-scripts <scratch>/evidence/inspect-src.json <scratch>/scripts  # ~4 s
```

Both paths absolute; the output directory must not exist (parent must).
Writes `files/origins/<hash>/<url path>`, `files/isolated/` and
`manifest.json`; 122 of 133 scripts were exported. Inline page scripts were
not exported (they may carry account data; do not seek them out).

## 4. Search offline

- Minification keeps string literals. Search for extension/node names
  (`name:"..."` inside `.create({`/`.extend({`), `data-*` attribute names,
  UI strings, route strings, keymap names (`addKeyboardShortcuts`), embedded
  `JSON.parse('...')` modules (example documents, theme data: parse them
  rather than run code).
- Find the chunk with a distinctive string (`grep -rl`), then read a bounded
  window around the match with a small Python script (`python3 -I`). Never
  print whole files. Write helper scripts with the file-write tool, not Bash
  heredocs (some heredocs were not written).
- The shell's grep (ugrep) rejects long `.{N}` quantified patterns
  ("exceeds complexity limits"): use Python for context windows.
- Identify libraries by residue: `data-radix-*`, `data-sonner-*`,
  `.cm-editor`, `@codemirror/state` error text, version literals in client
  bootstraps.
- **False positives:** a substring such as "monaco" matched a country name
  and "marked" an unrelated lexer. Check the surrounding context before
  concluding. A string in shipped code shows what is declared, not that a path
  executes: tag it OBSERVED (static), not as observed behaviour.
- Record identifiers and behaviour only; do not copy the target's code.

## 5. Optional commands

| Command | Result | Verdict |
|---|---|---|
| `inspect-web-event-listeners <endpoint> <target-id> '<selector>'` | 1.2 s, 1.4 MB, 40 listeners with chunk URL and column; selector is a required positional | Cheap, low value (library core handlers) |
| `discover-webmcp-tools <endpoint> <target-id>` | 1.2 s, 3 KB, 0 tools | Fast to confirm absence |
| `capture-web-screenshot <endpoint> <target-id>` | PNG embedded in JSON (288 KB), not a file | Skip unless the screen is safe to view |
| `analyze-web-bundle` | see below | Usually skip |

### analyze-web-bundle (slow, mostly not worth it)

```bash
rea analyze-web-bundle http://127.0.0.1:9222 <target-id> --detail summary \
  --evidence_output <scratch>/evidence/bundle.json --fetch-source-maps \
  --observation-ms 1500 \
  --view '{"kind":"web-bundle","collection":"endpoints","limit":32}'
```

- Took ~78 s and wrote a 17 MB evidence file (mostly fetched vendor maps);
  stdout was one 25 KB page of mostly API names. It does not hold first-party
  script text, so it cannot replace steps 2-3.
- Its unique value: the source-map verdict. 117 of 120 first-party maps were
  declared but returned HTTP 404; only 3 vendor maps were fetched. One script
  hit the 30 s per-script deadline (reported as an explicit unknown; raise
  `--analysis-timeout-ms` only if needed).
- `--detail summary` needs `--evidence_output` (never overwrites; use a new
  path) **and** `--view`. Collections: `endpoints`, `inferences`, `summary`;
  `summary` takes no `limit`.
- Page the saved file without reopening the target:

```bash
rea inspect-analysis-view \
  '{"source":{"kind":"retained-evidence","evidence_id":"<parent-evidence-id>"},"view":{"kind":"web-bundle","collection":"endpoints","offset":32,"limit":5}}' \
  --evidence-bundle <scratch>/evidence/bundle.json --format json
```

`coverage.next_offset` and `exhausted` say where to continue.

## 6. Errors and fixes

| Error | Fix |
|---|---|
| `VALIDATION_ERROR` on `list-browser-targets` | Pass `http://127.0.0.1:9222` positionally |
| `invalid_request`, `view` missing | Add `--view` (also required with `--detail summary`) |
| `unknown_argument` on `view.limit` | `summary` collection takes no `limit`; use `endpoints` |
| `inspect-analysis-view` lists `source` missing / `parent_evidence_id` unknown | Use `source: {kind: retained-evidence, evidence_id}` |

Each error carries a `remediation` and `details.issues[]` naming the path.
Fastest route to a correct input shape: `rea guidance --query "<exact field or
tool name>"`, then `rea guidance --action read --locator <locator>` (the
content is in the `content` field; all query words must match). Guidance is a
bundled snapshot. `<command> --help` shows positionals; `rea --help` is only a
command list (~14 KB).

## 7. Tagging and write-up

Tag each conclusion OBSERVED (runtime: from live CDP output; static: from
the exported scripts) with evidence id and command, INFERRED (give the basis)
or UNKNOWN (say what was tried). Sources and evidence ids go in a table.

## Environment notes

- The Bash permission classifier returned "no verdict" transiently; retrying
  the same call once worked.
- _Unverified_: behaviour on apps that load code lazily after interaction
  (only the idle page was inspected; acting on the page is not allowed).
