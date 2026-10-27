# ADR: One clipboard writer on macOS — pbcopy, with Alacritty's OSC 52 disabled

Date: 2026-10-27
Status: Accepted

## Context

Alacritty (0.17, macOS) kept flashing a yellow message bar on copy-on-select:

    [WARN] Unable to store text in clipboard: NSPasteboard#writeObjects: returned false

The copy itself always succeeded. Under tmux, one selection in Claude Code
writes the clipboard several ways at once:

1. `pbcopy`, run directly by Claude Code;
2. raw OSC 52, which tmux re-emits to the outer terminal (`set-clipboard on`);
3. OSC 52 wrapped in DCS passthrough (`allow-passthrough on`).

Alacritty handles (2) and (3) with an NSPasteboard clear-then-write. When
`pbcopy` changes the pasteboard between those two calls, `writeObjects`
returns false and Alacritty warns. `pbcopy` already put the same text there,
so the warning is harmless, but it shows up on most copies.

### Earlier attempt that did nothing

An earlier fix set `[debug] log_level = "Error"` in `alacritty.toml` to hide
warnings. It never worked. Alacritty applies the CLI options over the config
(`alacritty/src/cli.rs`, v0.17.0):

```rust
config.debug.log_level = max(config.debug.log_level, self.log_level());
```

The CLI default is `Warn`, so the config value can only make logging more
verbose. Only launching with `-q` lowers it, and the Dock can't pass
arguments.

## Options considered

| | Warning gone | Cost |
|---|---|---|
| **Disable Alacritty OSC 52; tmux `copy-command pbcopy`** | Yes — removes the race | OSC 52 from inside ssh (a remote nvim/tmux yank) no longer reaches the Mac clipboard in Alacritty |
| Wrapper `.app` launching `alacritty -q` | Hidden, race remains | Hides *all* warnings incl. config typos; a non-standard Dock item to maintain |
| Leave it | No | Constant noise |

## Decision

**Make pbcopy the only clipboard writer on macOS.**

- `scripts/init` writes `osc52 = "Disabled"` into the machine-local
  `~/.config/alacritty/local.toml`, macOS only. Linux keeps the default
  `OnlyCopy`, because it has no pbcopy and nothing there races.
- `src/.tmux.conf` sets `copy-command pbcopy` wherever `pbcopy` exists. With
  OSC 52 now ignored, tmux copy-mode and mouse-drag copies need it.
  `set-clipboard on` stays, so other outer terminals (Ghostty, or Linux) still
  get OSC 52.
- The ineffective `[debug] log_level` block is removed from `alacritty.toml`.

## Consequences / revisit if

- **Remote copy via OSC 52 is lost in Alacritty on macOS.** If it is needed
  again, set `osc52 = "OnlyCopy"` in local.toml and accept the warning, or
  use Ghostty for those sessions (Ghostty is unaffected). Upstream fixes
  could also make this unnecessary: Alacritty retrying or ignoring a
  pasteboard changed under it, or Claude Code offering a single-path copy.
- Re-check after Alacritty upgrades. If `debug.log_level` ever becomes able to
  lower verbosity, that is a cheaper fallback.
- `pbcopy` from a tmux server started outside the GUI login session (for
  example over ssh into the Mac) may not reach the user's pasteboard. That
  setup hasn't been seen in practice.
