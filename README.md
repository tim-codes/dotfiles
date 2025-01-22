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
