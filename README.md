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

## references

* https://switowski.com/blog/favorite-cli-tools

## notes

* when running the scripts, it is most reliable to open zsh in native terminal (not alacritty or another emulator), then run eg `./dev/dotfiles/scripts/init`