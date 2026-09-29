# Terminal keymap

Prefix is `C-a` (not `C-b`). Alacritty attaches to session `main`; the Ghostty
dropdown attaches to `scratch` — kept apart so the half-height dropdown never
reflows the full-screen window.

## Closing and renaming from the window list

`C-a w` opens **tree mode**, a browsable tree of sessions, windows and panes —
not a plain list, so the usual kill and rename bindings don't apply. Inside it:

| Key | Does |
| --- | --- |
| `↑` `↓` | Move |
| `x` | Kill selected item — no confirmation |
| `X` | Kill all tagged items |
| `t` | Tag / untag an item |
| `:` then `rename-window -t %% <name>` | Rename selected window — `%%` is the selection |
| `Enter` | Switch to it (then `C-a ,` to rename) |
| `f` | Filter |
| `q` | Exit |

## Windows

| Key | Does |
| --- | --- |
| `C-a c` | New window (opens in `$HOME`) |
| `C-a &` | Kill window (asks y/n) |
| `C-a w` | tmux-home — every window, type to filter |
| `C-a F` | fzf menu — rename, move, swap, kill windows / sessions / panes |
| `C-a 0`…`9` | Jump to window by number |
| `C-a a` | Last window |
| `C-a C-n` / `C-p` | Next / previous window |
| `C-a ,` | Rename window |
| `C-a .` | Move window to another index |
| `C-a f` | tmux-home (same as `C-a w`) |

## tmux-home (`C-a w` / `C-a f`)

A full-window list of every window, session name first, current session on
top, with a preview.

| Key | Does |
| --- | --- |
| type | Filter by session, window name, command or path |
| `↑` `↓` / `C-n` `C-p` / `C-j` `C-k` | Move |
| `Enter` | Switch to that window and close |
| `C-r` | Rename in place (`Enter` saves, `Esc` cancels) |
| `M-r` | Back to the automatic name |
| `C-o` / `F1` | Toggle preview / help |
| `Esc` | Clear the filter, then close |

## Organising (tmux-fzf)

A full-window fzf popup: type to filter, with a preview of the selection.

| Key | Does |
| --- | --- |
| `C-a F` | Menu: window / session / pane / command / keybinding |
| `C-a F` → `window` | switch, link, move, swap, rename, kill |
| `C-a F` → `session` | switch, new, rename, detach, kill |
| `C-a F` → `pane` | switch, break, join, swap, layout, kill, resize |
| `↑` `↓` / `C-k` `C-j` | Move |
| `Tab` / `S-Tab` | Mark / unmark for multi-select (e.g. kill several) |
| `Esc` | Back out |

**Rename a window:** `C-a F` → `window` → `rename` → pick the window → type
the name at the `Window Name:` prompt (a strip at the top) → `Enter`. For the
current window, `C-a ,` is quicker.

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
| `M-h` `M-j` `M-k` `M-l` | Resize by 5 cells — no prefix, left `⌥` is `M-` |

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

## Worktrees (worktrunk)

Shell commands, not keys. Worktrees land beside the repo as `../<repo>-<branch>`.

| Command | Does |
| --- | --- |
| `wt switch -c <branch>` | New branch off the default branch, in a new worktree, and `cd` there |
| `wt switch <branch>` | Go to a branch's worktree, creating it if needed |
| `wt switch` | Picker over all worktrees |
| `wt switch ^` / `-` | Default branch / previous worktree |
| `wt switch -c <branch> -x fish -- -c claude` | …and start Claude there (`claude-exxo` for work) |
| `wt list` | Worktrees with 🤖 working / 💬 waiting Claude sessions |
| `wt list --full` | Adds CI status and summaries |
| `wt merge` | Squash, rebase onto default, merge, remove the worktree |
| `wt remove` | Remove this worktree and its branch, if merged |

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
| `⌘ ←` / `→` | Start / end of the command line |
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
- Only the left `⌥` is Alt (Alacritty, Ghostty). Type `#` / `€` with the
  right one: `⌥3` / `⌥2`. iTerm2 keeps both as plain Option, so no `M-` there.
- `wt switch -x claude` runs the bare binary, skipping the account wrappers
  (it lands in the retired `~/.claude`). Go through fish: `-x fish -- -c claude`.
- Remove worktrees with `wt remove` / `wt merge`, never `git worktree remove`:
  worktrunk first moves the Claude transcripts to the main checkout, and
  refuses while a session is still running in the worktree.
