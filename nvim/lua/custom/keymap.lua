opts = { expr = true, silent = true }

-- Keymaps for better default experience
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("n", "<leader>w", "<cmd>w!<CR>")
-- vim.keymap.set("i", "jk", "<esc>", opts)
--
--
--
vim.keymap.set("n", "<leader>m", "<cmd>NERDTreeToggle<CR>")
vim.keymap.set("n", "<leader>q", "<cmd>bd!<CR>")


