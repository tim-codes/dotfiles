---
name: reauth
description: Re-authenticate Tim's workstation in one pass — OrbStack/Docker, the exxo and homelab secret caches, 1Password CLI, gcloud (+ADC), gh, pulumi (+ESC), az, and the MCP servers each Claude context needs — by running `scripts/claude-reauth` and relaying its table. Use before an unattended or overnight run, after a laptop reboot, when a squad `preflight blocked` comes back, when a session hits an expired login, or when Tim says "/reauth".
---

# Re-auth the workstation

Everything lives in one script in the dotfiles primary checkout:

```bash
$HOME/dev/dotfiles/scripts/claude-reauth --check                 # report only
$HOME/dev/dotfiles/scripts/claude-reauth                         # report, then run the missing logins
$HOME/dev/dotfiles/scripts/claude-reauth --context exxo --ttl-hours 16
```

`--context personal|exxo|exxo-personal|all` (default `all`) limits the
context-specific checks; `--ttl-hours N` (default 12) sets the cache TTL the
unattended run should start with. Exit 0 all ok, 1 something still needs
auth, 2 usage error. The script never prints a token, secret or id — only the
email / account name the tools themselves show on status. Don't run the
underlying status commands by hand to "double-check"; several print tokens or
ids (`gh auth status`, `az account show`, `op whoami`).

## Procedure

1. Run `--check` and relay the **Summary** table to Tim as-is (item, status,
   hint). Statuses: `ok`, `needs-auth` (a login or start is due — the hint
   names the command), `failed` (broken, not an auth problem — say so),
   `skipped` (not installed / not applicable).
2. All ok → say so and stop. Otherwise, before running anything interactive,
   tell Tim what will appear: browser OAuth windows (gcloud, ADC, az, MCP
   `claude mcp login`) and possibly a Touch ID prompt (1Password). Then run
   the script without `--check` in the background (`run_in_background`) and
   wait for it — at least 10 minutes; never kill it because it looks hung, it
   is waiting on Tim. It runs one login at a time, re-checks, and prints a
   final Summary; relay that.
3. Rows whose hint says **needs a terminal** (`gh auth login`, `pulumi login`,
   `op signin` with no account configured) cannot run from a session: give
   Tim the exact command to run in his own terminal — or have him run the
   whole script there (`~/dev/dotfiles/scripts/claude-reauth`), which handles
   everything in one pass.
4. **In-session MCP steps.** The script prints them grouped by context when
   an MCP server still needs auth (normally `claude mcp login` handles it from
   the CLI; this is the fallback, and the only path for `pending approval`).
   Tell Tim exactly, per context: launch the context's wrapper (`claude`,
   `claude-exxo`, `claude-exxo-personal`), type `/mcp`, select the named
   server, press Enter, approve in the browser. One pass per context.
5. Relay the "Unattended run" TTL lines: the secret caches have no warm
   command, so the run itself must carry `EXXO_SECRET_CACHE_TTL_SECONDS` (and
   `HOMELAB_1P_CACHE_TTL_SECONDS` for homelab work) or cached items expire
   after the default hour and the run hangs on an unapprovable Touch ID.

## Facts the table depends on

- **Datadog is EU.** The exxo contexts get a user-scope `datadog` server from
  `files/claude/mcp.exxo.json` pointing at `https://mcp.datadoghq.eu/v1/mcp`,
  so its OAuth goes straight to the EU approve flow. The engineering plugin's
  `plugin:engineering:datadog` is the US site and is denied — don't auth it.
- `failed … not configured in this context` for a repo-managed server means
  the context hasn't been synced: run `~/dev/dotfiles/scripts/claude-sync`.
- 1Password `ok … CLI session idle` is normal with app integration (the CLI
  session lapses after 10 idle minutes); the non-check run does one `op
  signin` anyway, which also unlocks the desktop app after a reboot.
- Never stop either secret-cache container — they are machine-wide; the
  script only starts them.
- Which MCP servers count is `files/claude/reauth-needed.toml` in the dotfiles
  repo (names exactly as `claude mcp list` prints them). Change it there, via
  a dotfiles worktree, not here.
