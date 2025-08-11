# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal dotfiles repository for macOS and Linux development environment setup. It uses GNU Stow for symlink management and provides shell configurations for both Fish and Zsh.

## Key Commands

### Initial Setup
- `~/dev/dotfiles/scripts/init` - Complete initial setup (creates configs, installs dependencies)
- `~/dev/dotfiles/scripts/setup-macbook` - macOS-specific setup
- `~/dev/dotfiles/scripts/setup-linux` - Linux-specific setup

### Maintenance
- `~/dev/dotfiles/src/bin/deps-up` - Update all dependencies (brew, cargo, npm, pnpm)
- `~/dev/dotfiles/scripts/brew-update` - Update Homebrew packages
- `~/dev/dotfiles/scripts/cargo-update` - Update Rust packages
- `restow` - Update symlinks after adding new files to src/

### Development
- No build/compile step required - this is a configuration repository
- No tests - configuration files are validated by their respective applications

## Architecture

### Directory Structure
- `scripts/` - Setup and maintenance scripts
- `src/` - Configuration files managed by Stow (symlinked to `~/.config/`)
- `src/bin/` - Custom utility scripts
- `assets/` - Fonts and other static resources

### Configuration Loading Order

**Fish Shell:**
```
config.fish > local.sh, $platform.fish > common.fish, local.fish
```

**Zsh:**
```
.zshrc > local.sh, zsh_$platform > zsh_common, zsh_local
``` s

### Key Configuration Files
- `~/.config/local.sh` - Environment variables (shared between shells)
- `~/.config/fish/local.fish` - Fish-specific overrides
- `~/.config/zsh/zsh_local` - Zsh-specific overrides
- `~/.gpg.gitconfig` - GPG signing configuration

### Stow Integration
The repository uses GNU Stow to manage symlinks. All files in `src/` are symlinked to the home directory structure. After adding new files to `src/`, run `restow` to update symlinks.

### Platform Detection
The setup scripts automatically detect platform (`mac` or `linux`) and load appropriate configurations. Platform-specific files are named with suffixes like `mac.fish` or `zsh_mac`.

## Important Notes

- The init script should be run from native terminal (not alacritty) for best compatibility
- Fisher plugin installation can be flaky between different shells
- GPG keys are stored locally, not integrated with 1Password (stored there as reference only)
- Homebrew updates are throttled to run at most once every 20 minutes via timestamp check
