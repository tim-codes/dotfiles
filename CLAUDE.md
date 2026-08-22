# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal dotfiles repository for macOS and Linux development environment setup. It uses GNU Stow for symlink management and provides shell configurations for both Fish and Zsh.

## Key Commands

### Initial Setup
- `scripts/bootstrap` - Fresh-machine bootstrap (curl-able from main): Xcode CLT, 1Password SSH agent config, clone to ~/dev/dotfiles, then runs init
- `~/dev/dotfiles/scripts/init` - Complete initial setup (creates configs, installs dependencies)
- `~/dev/dotfiles/scripts/setup-macbook` - macOS-specific setup
- `~/dev/dotfiles/scripts/setup-linux` - Linux-specific setup

### Maintenance
- `~/dev/dotfiles/src/bin/deps-up` - Update all dependencies (brew, cargo, npm, pnpm)
- `~/dev/dotfiles/scripts/brew-update` - Update Homebrew packages
- `~/dev/dotfiles/scripts/cargo-update` - Update Rust packages
- `~/dev/dotfiles/scripts/firefox-prefs` - Link codified Firefox prefs into each installation's active profile (only needed for a new profile/machine; the link means repo edits apply on Firefox restart)
- `restow` - Update symlinks after adding new files to src/

### Development
- No build/compile step required - this is a configuration repository
- No tests - configuration files are validated by their respective applications

## Architecture

### Directory Structure
- `scripts/` - Setup and maintenance scripts
- `src/` - Configuration files managed by Stow (symlinked to `~/.config/`)
- `src/bin/` - Custom utility scripts (gitignored by default — add a `!` negation in .gitignore per file)
- `src/Library/LaunchAgents/` - launchd user agents; stows into the existing real `~/Library/LaunchAgents/`
- `docs/adr/` - Architecture decision records
- `assets/` - Fonts and other static resources

### Configuration Loading Order

**Fish Shell:**
```
config.fish > local.sh, $platform.fish > common.fish, local.fish
```

**Zsh and bash** — both load one shared file, `~/.config/shell/common.sh`,
which sources `local.sh` and builds PATH:
```
zsh:   .zshenv > common.sh > local.sh          (EVERY zsh, incl. non-interactive)
       [login]       /etc/zprofile (path_helper) > .zprofile > common.sh again
       [interactive] .zshrc  (nvm only)
bash:  .bashrc > common.sh > local.sh, then interactive-only aliases/prompt
```

- **zsh is the login shell** on these machines (`scripts/setup-linux` runs
  `chsh -s $(which zsh)`, macOS defaults to `/bin/zsh`) even though interactive
  use is fish. ssh one-liners, cron, scripts and Claude Code all land in zsh,
  and `.zshenv` is the only file they read — so nothing shared may live in
  `.zshrc`.
- zsh is deliberately **not** at parity with fish. It is the redundant fallback
  for machines and contexts without fish, so it gets variables and PATH and
  nothing else; aliases, prompt and completions stay in `.bashrc` and the fish
  config.
- `.zprofile` re-sources `common.sh` because macOS's `/etc/zprofile` runs
  `path_helper`, which reorders PATH *and* adds the `/etc/paths.d` entries
  after `.zshenv` has already run.
- Earlier versions of this file described `zsh_$platform`/`zsh_common` files.
  They never existed, and `local.sh` sourcing was commented out in both
  `.zshenv` and `.zprofile` — zsh had no shared config at all.

### Key Configuration Files
- `~/.config/local.sh` - Environment variables (shared between all three shells)
- `~/.config/shell/common.sh` - Shared bash+zsh config: variables + PATH
- `~/.config/fish/local.fish` - Fish-specific overrides
- `~/.gpg.gitconfig` - GPG signing configuration

### Stow Integration
The repository uses GNU Stow to manage symlinks. All files in `src/` are symlinked to the home directory structure. After adding new files to `src/`, run `restow` to update symlinks.

### Platform Detection
The setup scripts automatically detect platform (`mac` or `linux`) and load appropriate configurations. Platform-specific files are named with suffixes like `mac.fish` or `zsh_mac`.

## Editing Workflow

**Always use a git worktree for branch work in this repo — never switch
branches in the primary `~/dev/dotfiles` checkout.** Stow symlinks the live
config on this machine (`~/.zshrc`, `~/.config/fish/*`, the per-account
`~/.claude-*/CLAUDE.md` and `settings.json` that `scripts/claude-sync`
reads from here, etc.) straight into this checkout's `src/` — the symlink
targets are files on disk at a fixed path, not a particular git ref. Check
out a different branch in the primary checkout and every one of those live
files changes content immediately, machine-wide, including mid-edit or
half-finished branch state — until you check back out to `main`.

To edit anything, `git worktree add ../dotfiles-<branch> <branch>` (or
`-b <branch>` for a new one) and do the work there instead. The primary
checkout stays parked on `main`, so the symlinks keep resolving to `main`'s
content for the whole time a branch is being worked on, and the worktree
branches, commits, pushes and gets removed (`git worktree remove`)
independently of it.

## Important Notes

- The init script should be run from native terminal (not alacritty) for best compatibility
- Fisher plugin installation can be flaky between different shells
- Git commit signing uses 1Password SSH agent (key labeled "Git" in 1Password, deployed to ~/.ssh/git-signing.pub)
- The init script detects WSL and uses `op-ssh-sign-wsl.exe` for commit signing (vs native paths on mac/linux)
- Homebrew updates are throttled to run at most once every 20 minutes via timestamp check
- Scroll direction: LinearMouse reverses mice (its "bypass other apps" toggle leaves Logi Options+-managed MX mice alone; macOS stays "natural" for the trackpad) — see docs/adr/2026-08-17-per-device-scroll-direction.md
- Firefox: prefs are codified in `src/.config/firefox/user.js` and symlinked into the profile — `about:config` edits reset on restart, change the repo file instead. A launchd watchdog (`src/bin/firefox-tab-watchdog`) flags runaway content processes; it ships in `warn` mode, flip `FF_WATCHDOG_MODE` to `enforce` in the plist to let it kill. See docs/adr/2026-08-22-firefox-resource-containment.md
