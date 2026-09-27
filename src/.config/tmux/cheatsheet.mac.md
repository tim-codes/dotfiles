
## macOS: where `⌘.` comes from

`⌘.` is not a tmux binding — tmux never sees Cmd. Both terminals rebind it to
send tmux's real prefix, `C-a` (byte `\x01`):

| Terminal | Binding |
|---|---|
| Alacritty | `alacritty.toml` — `[[keyboard.bindings]]` `key = "."`, `mods = "Command"`, `chars = "\u0001"` |
| Ghostty | `ghostty/config` — `keybind = super+period=text:\x01` |

If `⌘.` stops working:

- Press `C-a` directly. If that works, the fault is the terminal rebind, not tmux.
- Something may have grabbed the chord globally before the terminal sees it — check
  recently installed apps' shortcut settings.
- Alacritty reloads its config on save; Ghostty needs a config reload (`⌘⇧,`).
- `tmux show-options -g prefix` should print `prefix C-a`.
