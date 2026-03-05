# Shell Loading Order and PATH Configuration

This document explains how shells load configuration files, how macOS manages PATH, and how Claude Code interacts with your shell environment.

## Table of Contents
- [Zsh Load Order](#zsh-load-order)
- [macOS path_helper Utility](#macos-path_helper-utility)
- [Claude Code Shell Behavior](#claude-code-shell-behavior)
- [Troubleshooting](#troubleshooting)

---

## Zsh Load Order

Zsh loads different configuration files depending on whether the shell is interactive and/or a login shell.

### Interactive Login Shell
**When**: `zsh -l`, SSH sessions, terminal login, macOS Terminal.app new window/tab

Load order:
1. `~/.zshenv`
2. `/etc/zprofile`
3. `~/.zprofile`
4. `/etc/zshrc`
5. `~/.zshrc`
6. `/etc/zlogin`
7. `~/.zlogin`

On exit:
- `~/.zlogout`
- `/etc/zlogout`

### Interactive Non-Login Shell
**When**: Typing `zsh` from an existing shell, new terminal tab (in some configurations)

Load order:
1. `~/.zshenv`
2. `/etc/zshrc`
3. `~/.zshrc`

### Non-Interactive Shell
**When**: Running scripts, command substitution, `zsh -c 'command'`

Load order:
1. `~/.zshenv` **only**

### Configuration File Purposes

- **`.zshenv`** - ALWAYS loaded (all shell types). Use for environment variables needed by scripts and non-interactive shells. Critical for Claude Code.
- **`.zprofile`** - Login shells only. Use for PATH setup and once-per-session initialization.
- **`.zshrc`** - All interactive shells. Use for aliases, functions, prompts, keybindings, completion.
- **`.zlogin`** - Login shells only, runs AFTER `.zshrc`. Rarely used.

---

## macOS path_helper Utility

### Overview

The `path_helper` utility (`/usr/libexec/path_helper`) constructs PATH and MANPATH environment variables by reading system configuration files. It's called from `/etc/zprofile`, `/etc/profile`, and `/etc/csh.login`.

### Sources for PATH (in order)

1. **`/etc/paths`** - Base system paths
   ```
   /usr/local/bin
   /System/Cryptexes/App/usr/bin
   /usr/bin
   /bin
   /usr/sbin
   /sbin
   ```

2. **`/etc/paths.d/*`** - Additional paths (one per line, per file)
   - Files are read in lexicographic order
   - System and applications can add files here
   - Survives system upgrades (unlike `/etc/paths` which may be replaced)

3. **Existing `$PATH`** - Your current PATH value is preserved

### How path_helper Works

1. Reads `/etc/paths`
2. Appends all files from `/etc/paths.d/` (in alphabetical order)
3. **Prepends** this combined list to your existing `$PATH`
4. Removes duplicates (later occurrences are removed, first occurrence wins)

**Important**: Because `path_helper` prepends system paths, if you want your custom paths (like `/opt/homebrew/bin`) to take precedence, you must set PATH **after** `path_helper` runs.

### PATH Precedence Strategy

Since `/etc/zprofile` (which calls `path_helper`) runs **before** `~/.zprofile`:

```zsh
# /etc/zprofile runs first (contains path_helper)
# Then ~/.zprofile runs

# In ~/.zprofile:
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
```

This ensures Homebrew binaries override system binaries when there are name conflicts.

### Sources for MANPATH

1. **`/etc/manpaths`** - Base manual page paths
2. **`/etc/manpaths.d/*`** - Additional manual paths
3. Existing `$MANPATH` (only modified if already set)

---

## Claude Code Shell Behavior

### Shell Type

Claude Code uses a **non-interactive login shell** when executing bash commands via the Bash tool.

Specifically: `zsh -l` (or whatever your system default shell is, without the `-i` interactive flag)

### Load Order for Claude Code

1. `~/.zshenv`
2. `/etc/zprofile` (runs `path_helper`)
3. `~/.zprofile`
4. ~~`/etc/zshrc`~~ (skipped - not interactive)
5. ~~`~/.zshrc`~~ (skipped - not interactive)

This is why interactive configurations (aliases, prompts, keybindings) in `.zshrc` are not available in Claude Code.

### PATH Inheritance

**Critical**: Claude Code **inherits the environment** from the parent shell where you run the `claude` command.

Process hierarchy:
```
Fish/Zsh/Bash (your terminal shell)
  └─ claude (Claude Code process)
      └─ /bin/zsh -l (Bash tool execution)
```

**What this means**:

1. Your terminal shell (e.g., Fish) has its own PATH with all your customizations
2. You run `claude` from that shell
3. The `claude` process inherits Fish's environment variables, including `$PATH`
4. When Claude Code runs a command via the Bash tool:
   - It spawns `/bin/zsh -l`
   - That zsh loads `.zshenv` and `.zprofile`
   - `/etc/zprofile` runs `path_helper`, which:
     - Reads `/etc/paths` and `/etc/paths.d/`
     - **Preserves the inherited Fish PATH** (doesn't discard it)
     - Prepends system paths
     - Deduplicates
   - Your `.zprofile` may set PATH again, but `path_helper` already ran with the inherited PATH

**Result**: Claude Code's shell sees a combination of:
- System paths (from `path_helper`)
- Your Fish/Zsh PATH (inherited from parent)
- Paths set in `.zprofile`

### System Shell (No Override)

Claude Code currently uses your **system default shell** as determined by macOS. There is no way to override this to use a different shell (e.g., Fish instead of Zsh).

The system shell is typically:
- `/bin/zsh` on modern macOS (Catalina and later)
- `/bin/bash` on older macOS versions

To check your system default shell:
```bash
echo $SHELL
dscl . -read ~/ UserShell
```

### Why .zshenv is Critical

Since `.zshenv` is the **only** file loaded by non-interactive shells, it's critical for:
- Scripts that run in non-interactive contexts
- Claude Code (which uses non-interactive login shells)
- Command substitution and subshells
- Cron jobs and automation

However, be careful:
- Keep `.zshenv` minimal and fast
- Avoid interactive-only configurations
- Don't print output (breaks command substitution)
- Focus on environment variables and PATH

---

## Troubleshooting

### PATH Changes Not Reflecting in Claude Code

**Problem**: You updated your shell configuration but Claude Code still sees the old PATH.

**Root Cause**: Claude Code inherits the environment from the parent shell where you launched `claude`. If you started Claude Code before updating your configs, it has the old PATH.

**Solution**:
1. Exit Claude Code completely
2. **Restart your terminal shell** (Fish/Zsh) or reload configs:
   ```fish
   # In Fish
   exec fish

   # In Zsh
   exec zsh -l
   ```
3. Launch Claude Code again with `claude`

The new Claude Code session will inherit the updated PATH.

### Debugging PATH Issues

Check what each stage contributes:

```bash
# 1. Check raw path_helper output (without your configs)
/usr/libexec/path_helper -s

# 2. Check PATH in a clean login shell
env -i HOME=$HOME USER=$USER /bin/zsh -l -c 'echo $PATH'

# 3. Check PATH in your current shell
echo $PATH | tr ':' '\n' | nl

# 4. Find which file provides a specific path
grep -r "/specific/path" /etc/paths /etc/paths.d/ ~/.zshenv ~/.zprofile
```

### PATH Deduplication

If you see duplicate paths, remember:
- `path_helper` deduplicates automatically
- Setting PATH multiple times in different files can cause confusion
- First occurrence wins in deduplication

Best practice: Set PATH once in `.zprofile` (for login shells) or `.zshenv` (for all shells).

### Testing Shell Types

Determine what type of shell you're in:

```zsh
# Check if login shell
[[ -o login ]] && echo "Login shell" || echo "Not a login shell"

# Check if interactive
[[ -o interactive ]] && echo "Interactive" || echo "Not interactive"

# Check shell name
echo $0
```

---

## Best Practices

### For Zsh Configuration

1. **`.zshenv`** - Environment variables needed everywhere (minimal, fast)
2. **`.zprofile`** - PATH setup, login-time initialization
3. **`.zshrc`** - Interactive config only (aliases, functions, prompts)
4. **`.zlogin`** - Rarely needed; use `.zprofile` instead

### For PATH Management

1. Set PATH in `.zprofile` (or `.zshenv` if needed for non-login shells)
2. Put custom paths **first** to override system paths:
   ```zsh
   export PATH="/opt/homebrew/bin:$PATH"
   ```
3. Use `/etc/paths.d/` for system-wide additions (requires sudo)
4. Remember `path_helper` runs in `/etc/zprofile` before your `~/.zprofile`

### For Claude Code

1. Ensure critical environment variables are in `.zshenv` or `.zprofile`
2. Don't rely on `.zshrc` (not loaded by Claude Code)
3. Remember PATH is inherited from the parent shell
4. Restart your terminal shell after config changes, then restart Claude Code

---

## References

- `man zsh` - Zsh manual
- `man path_helper` - path_helper manual
- `/etc/zprofile` - System-wide zsh login profile
- `/etc/paths` and `/etc/paths.d/` - System PATH configuration
