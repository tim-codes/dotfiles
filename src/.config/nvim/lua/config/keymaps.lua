-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Re-assert vim-tmux-navigator's <C-hjkl> mappings (lua/plugins/tmux-navigator.lua).
-- LazyVim's defaults above set <C-hjkl> to plain window navigation on this same
-- VeryLazy event, loading after the plugin's own eager keymaps and overwriting
-- them, so tmux-side C-h/j/k/l would stop reaching into vim splits without this.
vim.keymap.set("n", "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", { desc = "Tmux Navigate Left" })
vim.keymap.set("n", "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>", { desc = "Tmux Navigate Down" })
vim.keymap.set("n", "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>", { desc = "Tmux Navigate Up" })
vim.keymap.set("n", "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>", { desc = "Tmux Navigate Right" })
