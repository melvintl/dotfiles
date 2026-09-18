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

-- Completion popup: the same keys nvim-cmp had, on the native popup menu.
-- Tab/S-Tab cycle items; when a snippet is active and no menu is open they
-- jump between tabstops instead (the built-in default that this map replaces).
local function pum_or(pum_key, snippet_dir, fallback)
  return function()
    if vim.fn.pumvisible() == 1 then
      return pum_key
    elseif vim.snippet.active({ direction = snippet_dir }) then
      return '<Cmd>lua vim.snippet.jump(' .. snippet_dir .. ')<CR>'
    end
    return fallback
  end
end
vim.keymap.set({ 'i', 's' }, '<Tab>', pum_or('<C-n>', 1, '<Tab>'), { expr = true, desc = 'Next completion / snippet stop' })
vim.keymap.set({ 'i', 's' }, '<S-Tab>', pum_or('<C-p>', -1, '<S-Tab>'), { expr = true, desc = 'Previous completion / snippet stop' })
-- Enter confirms the highlighted item, or the first one when nothing is
-- highlighted yet (cmp's `select = true`).
vim.keymap.set('i', '<CR>', function()
  if vim.fn.pumvisible() == 0 then
    return '<CR>'
  end
  return vim.fn.complete_info({ 'selected' }).selected == -1 and '<C-n><C-y>' or '<C-y>'
end, { expr = true, desc = 'Confirm completion' })
vim.keymap.set('i', '<C-Space>', function() vim.lsp.completion.get() end, { desc = 'Trigger completion' })
