# dotfiles

source order: 

```
config.fish > 
  local.fish, 
  $platform.fish > 
    common.fish
```

## contributing

* if new files are added to dotfiles/src, then run `restow` to update symlinks

## macbook setup

1. setup 1password, install ssh agent
2. clone dotfiles repo to ~/dev/dotfiles
3. `~/dev/dotfiles/scripts/init`
4. `gpg --generate-full-key`, use defaults, name="Tim O'Connell", email=<github-email>, no passphrase
(see: https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
5. follow instructions to add gpg key to github & gitlab
6. where there is multiple e.g. github ssh keys for the same domain, then download the public keys to `~/.ssh/`, and add entries for unique remote names to `~/.ssh/config`:
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
--> then use e.g. `git@skygit/<repo>.git` for the origin remote

## references

* https://switowski.com/blog/favorite-cli-tools

## notes

* when running the scripts, it is most reliable to open zsh in native terminal (not alacritty or another emulator), then run eg `./dev/dotfiles/scripts/init`