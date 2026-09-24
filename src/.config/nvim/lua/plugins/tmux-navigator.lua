-- Seamless navigation between neovim splits and tmux panes.
-- lazy = false: this must load eagerly. Tmux sends <C-hjkl> whether or not
-- neovim has loaded the plugin yet, so lazy-loading it on keys is a known
-- footgun. See https://github.com/christoomey/vim-tmux-navigator#lazynvim
--
-- LazyVim's own <C-hjkl> window-navigation keymaps are set later, on the
-- VeryLazy event, and would otherwise clobber the mappings below -- see the
-- override in lua/config/keymaps.lua.
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  keys = {
    { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", desc = "Tmux Navigate Left" },
    { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>", desc = "Tmux Navigate Down" },
    { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>", desc = "Tmux Navigate Up" },
    { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>", desc = "Tmux Navigate Right" },
    { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", desc = "Tmux Navigate Previous" },
  },
}
