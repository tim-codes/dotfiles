# dotfiles

source order: 

```
config.fish >
  local.sh, 
  $platform.fish > common.fish,
  local.fish

.zshenv >                               # EVERY zsh, incl. non-interactive
  ~/.config/shell/common.sh > local.sh
  [login]       .zprofile > common.sh again   # after /etc/zprofile path_helper
  [interactive] .zshrc                        # nvm only

.bashrc >
  ~/.config/shell/common.sh > local.sh,
  then interactive-only aliases/prompt
```

zsh is the fallback for machines and contexts without fish, so it gets the
minimal set — variables and PATH — not parity. It and bash read the same
`common.sh`, so the two cannot drift apart.

user should modify:
* ~/.config/local.sh         # variables (read by all three shells)
* ~/.config/fish/local.fish  # fish overrides

## contributing

* if new files are added to dotfiles/src, then run `restow` to update symlinks

## macbook setup

### prerequisites (manual)

1. install 1Password and sign in
2. 1Password Settings → Developer:
   * enable **Use the SSH Agent**
   * enable **Integrate with 1Password CLI**
   * enable **Generate SSH config file with bookmarked hosts**

### bootstrap (one command)

Run from the native macOS Terminal (not alacritty):

```sh
curl -fsSL https://raw.githubusercontent.com/tim-codes/dotfiles/main/scripts/bootstrap | zsh
```

This installs Xcode Command Line Tools, wires `~/.ssh/config` to the 1Password
SSH agent, clones this repo to `~/dev/dotfiles` (SSH, with submodules), then
runs `scripts/init`: local config files, homebrew + deps, stow symlinks, fish
plugins, fonts, alacritty (cask), tmux plugins (tpm), nvm/node, rust, poetry.
Safe to re-run at any point if a step fails.

### post-bootstrap (manual)

1. set the git signingkey in `~/.gpg.gitconfig` — commit signing uses the
   1Password SSH key (see the "Git" item in 1Password):
```.gpg.gitconfig
[user]
    signingkey = xxx
```
2. where there are multiple ssh keys for the same domain, see (a) below
3. remaining app installs: Arc Browser, SetApp, JetBrains Toolbox + VSCode

(a) where there is multiple e.g. github ssh keys for the same domain, then download the public keys to `~/.ssh/`, and add entries for unique remote names to `~/.ssh/config`:
```
Host github.com
  hostname github.com
  identityfile ~/.ssh/github.pub
  identitiesonly yes

Host skygit
  hostname github.com
  identityfile ~/.ssh/github_sky.pub
  identitiesonly yes

Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```
--> then use e.g. `gcl git@skygit:<workspace>/<repo>.git` for the origin remote

## references

* https://switowski.com/blog/favorite-cli-tools
* https://gist.github.com/edwhad/a25f728e6add3f6d1f7a483810e9d555
* https://bmaingret.github.io/blog/2022-02-15-1Password-gpg-git-seamless-commits-signing

## notes

* when running the init script, it is most reliable to open zsh in native terminal (not alacritty or another emulator), then run eg `./dev/dotfiles/scripts/init`
* storing GPG keys in 1password as a reference, but they are not integrated, the local GPG key is used for signing
* maybe this tool will help with the bash->fish PATH loading: https://github.com/edc/bass
* todo: the fisher install step is not idempotent and is super flaky between different shells

