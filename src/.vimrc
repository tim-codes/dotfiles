" Plain vim is the fallback editor here (nvim is the real one, configured in
" ~/.config/nvim); this file exists only so vim joins in tmux pane navigation.

" Having any vimrc stops vim loading its stock defaults.vim, so pull it in
" explicitly to keep vim behaving exactly as it did with no vimrc.
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

" vim-tmux-navigator: tmux forwards C-h/j/k/l to any pane running vim, and
" without the plugin stock vim swallows them. The tmux plugin checkout is the
" vim plugin too, so load it from there instead of installing a second copy.
" Missing on a machine without tmux plugins - then nothing changes.
if isdirectory(expand('~/.tmux/plugins/vim-tmux-navigator'))
  set runtimepath+=~/.tmux/plugins/vim-tmux-navigator
endif
