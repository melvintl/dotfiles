-- Keymaps for better default experience
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("n", "<leader><leader>", "<C-^>", { desc = "Alternate buffer" })
vim.keymap.set("i", "jk", "<Esc>", { desc = "Leave insert mode" })
vim.keymap.set("n", "<leader>q", ":bd <CR>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>w", ":w! <CR>", { desc = "Write file (force)" })
vim.keymap.set("n", "<leader>p", ":set wrap! <CR>", { desc = "Toggle line wrap" })
vim.keymap.set("n", "\\", ":noh<CR>", { desc = "Clear search highlight" })

vim.keymap.set("n", "<leader>m", ":NERDTreeToggle <CR>", { desc = "Toggle NERDTree" })
