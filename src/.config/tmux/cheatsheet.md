# Terminal keymap

Prefix is `C-a` (not `C-b`). Alacritty attaches to session `main`; the Ghostty
dropdown attaches to `scratch` — kept apart so the half-height dropdown never
reflows the full-screen window.

## Closing things from the window list

`C-a w` opens **tree mode**, a browsable tree of sessions, windows and panes —
not a plain list, so the usual kill bindings don't apply. Inside it:

| Key | Does |
| --- | --- |
| `↑` `↓` | Move |
| `x` | Kill selected item — no confirmation |
| `X` | Kill all tagged items |
| `t` | Tag / untag an item |
| `Enter` | Switch to it |
| `f` | Filter |
| `q` | Exit |

## Windows

| Key | Does |
| --- | --- |
| `C-a c` | New window (opens in `$HOME`) |
| `C-a &` | Kill window (asks y/n) |
| `C-a w` | Tree mode — browse everything |
| `C-a 0`…`9` | Jump to window by number |
| `C-a a` | Last window |
| `C-a C-n` / `C-p` | Next / previous window |
| `C-a ,` | Rename window |
| `C-a .` | Move window to another index |
| `C-a f` | Find window by name |

## Panes

| Key | Does |
| --- | --- |
| `C-a %` | Split side by side (opens in `$HOME`) |
| `C-a "` | Split top and bottom |
| `C-a x` | Kill pane (asks y/n) |
| `C-h` `C-j` `C-k` `C-l` | Move between panes — no prefix, passes into neovim |
| `C-a z` | Zoom pane to full window (toggle) |
| `C-a q` | Show pane numbers, press one to jump |
| `C-a ;` | Last pane |
| `C-a !` | Break pane out into its own window |
| `C-a {` / `}` | Swap pane with previous / next |
| `C-a Space` | Cycle layouts |
| `C-a M-←↑↓→` | Resize by 5 cells |

## Sessions

| Key | Does |
| --- | --- |
| `C-a d` | Detach — leaves everything running |
| `C-a s` | Session tree (`x` kills, `q` exits) |
| `C-a $` | Rename session |
| `C-a (` / `)` | Previous / next session |
| `C-a C-s` / `C-r` | Save / restore all sessions (resurrect) |
| `tmux ls` | List sessions from a shell |
| `tmux a -t main` | Attach to the Alacritty session |

## Agents

| Key | Does |
| --- | --- |
| `C-a u` | Agent picker — working / waiting / idle |
| `C-a y` | Launch an agent for this directory |
| `C-a e` | Toggle agent sidebar — this window |
| `C-a E` | Toggle agent sidebar — everywhere |

## Copy and scrollback

| Key | Does |
| --- | --- |
| `C-a [` | Enter copy mode |
| `v` then `y` | Select, then yank to the system clipboard |
| `/` / `?` | Search forward / back (`n`, `N` repeat) |
| `g` / `G` | Top / bottom of scrollback |
| `q` | Leave copy mode |
| `C-a ]` | Paste the tmux buffer |
| `C-a k` | Clear screen and scrollback |

## Outside tmux

| Key | Does |
| --- | --- |
| `§` | Toggle the Ghostty dropdown — global, from any app |
| `⌥ §` | Same, for keyboards without a `§` key |
| `⇧ Return` | Newline without submitting |
| `⌥ ←` / `→` | Move by word on the command line |
| `⌥ ⌫` | Delete previous word |
| `theme` | Switch theme everywhere at once |
| `th` | This cheatsheet |
| `h` | Fuzzy-search your shell aliases |

## Config

| Key | Does |
| --- | --- |
| `C-a R` | Reload `~/.tmux.conf` |
| `C-a I` | Install plugins declared in the config |
| `C-a U` | Update plugins |
| `C-a ?` | List every binding tmux knows |
| `C-a :` | tmux command prompt |
| `C-a C-a` | Send a literal `C-a` to the shell |

## Gotchas

- New windows and splits open in `$HOME`, not the current directory. tmux's
  defaults don't inherit the working directory.
- `&` and `x` prompt y/n. In tree mode, `x` does not — it kills immediately.
- `C-a k` clears scrollback; it moved off `C-k`, which pane navigation owns.
