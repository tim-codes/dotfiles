# dotfiles

source order: 

```
config.fish >
  local.sh, 
  $platform.fish > common.fish,
  local.fish

.zshrc >
  local.sh,
  zsh_$platform > zsh_common,
  zsh_local
```

user should modify:
* ~/.config/local.sh         # variables
* ~/.config/fish/local.fish  # fish overrides
* ~/.config/zsh/zsh_local    # zsh overrides

## contributing

* if new files are added to dotfiles/src, then run `restow` to update symlinks

## macbook setup

1. setup 1password, install ssh agent, then see 1.(a)
2. clone dotfiles repo to ~/dev/dotfiles
3. `~/dev/dotfiles/scripts/init`
4. `gpg --generate-full-key`, use defaults, name="Tim O'Connell", email=<github-email>, no passphrase
(see: https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
5. follow instructions to add gpg key to github & gitlab
6. set signingkey to `~/.gpg.gitconfig`:
```.gpg.gitconfig
[user]
    signingkey = xxx
```

1. (a) where there is multiple e.g. github ssh keys for the same domain, then download the public keys to `~/.ssh/`, and add entries for unique remote names to `~/.ssh/config`:
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
