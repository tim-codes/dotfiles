# Terminal keymap

Prefix is `⌘.` (Cmd+period; Super+. on Linux). Alacritty and Ghostty both
turn it into `C-a`, tmux's real prefix, so `C-a` works too - in any other
terminal, over ssh, or where the desktop grabs Super+. Everything below is
written as `⌘.` then the key. Alacritty attaches to session `main`; the Ghostty
dropdown attaches to `scratch` — kept apart so the half-height dropdown never
reflows the full-screen window.

## Closing things from the window list

`⌘. w` opens **tree mode**, a browsable tree of sessions, windows and panes —
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
| `⌘. c` | New window (opens in `$HOME`) |
| `⌘. &` | Kill window (asks y/n) |
| `⌘. w` | Tree mode — browse everything |
| `⌘. 0`…`9` | Jump to window by number |
| `⌘. a` | Last window |
| `⌘. C-n` / `C-p` | Next / previous window |
| `⌘. ,` | Rename window |
| `⌘. .` | Move window to another index |
| `⌘. f` | Find window by name |

## Panes

| Key | Does |
| --- | --- |
| `⌘. %` | Split side by side (opens in `$HOME`) |
| `⌘. "` | Split top and bottom |
| `⌘. x` | Kill pane (asks y/n) |
| `C-h` `C-j` `C-k` `C-l` | Move between panes — no prefix, passes into neovim |
| `⌘. z` | Zoom pane to full window (toggle) |
| `⌘. q` | Show pane numbers, press one to jump |
| `⌘. ;` | Last pane |
| `⌘. !` | Break pane out into its own window |
| `⌘. {` / `}` | Swap pane with previous / next |
| `⌘. Space` | Cycle layouts |
| `⌘. M-←↑↓→` | Resize by 5 cells |

## Sessions

| Key | Does |
| --- | --- |
| `⌘. d` | Detach — leaves everything running |
| `⌘. s` | Session tree (`x` kills, `q` exits) |
| `⌘. $` | Rename session |
| `⌘. (` / `)` | Previous / next session |
| `⌘. C-s` / `C-r` | Save / restore all sessions (resurrect) |
| `tmux ls` | List sessions from a shell |
| `tmux a -t main` | Attach to the Alacritty session |

## Agents

| Key | Does |
| --- | --- |
| `⌘. u` | Agent picker — working / waiting / idle |
| `⌘. y` | Launch an agent for this directory |
| `⌘. e` | Toggle agent sidebar — this window |
| `⌘. E` | Toggle agent sidebar — everywhere |

## Copy and scrollback

| Key | Does |
| --- | --- |
| `⌘. [` | Enter copy mode |
| `v` then `y` | Select, then yank to the system clipboard |
| `/` / `?` | Search forward / back (`n`, `N` repeat) |
| `g` / `G` | Top / bottom of scrollback |
| `q` | Leave copy mode |
| `⌘. ]` | Paste the tmux buffer |
| `⌘. k` | Clear screen and scrollback |

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
| `⌘. R` | Reload `~/.tmux.conf` |
| `⌘. I` | Install plugins declared in the config |
| `⌘. U` | Update plugins |
| `⌘. ?` | List every binding tmux knows |
| `⌘. :` | tmux command prompt |
| `⌘. ⌘.` | Send a literal `C-a` to the shell |

## Gotchas

- New windows and splits open in `$HOME`, not the current directory. tmux's
  defaults don't inherit the working directory.
- `&` and `x` prompt y/n. In tree mode, `x` does not — it kills immediately.
- `⌘. k` clears scrollback; it moved off `C-k`, which pane navigation owns.
