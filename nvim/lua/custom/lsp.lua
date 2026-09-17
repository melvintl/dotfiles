-- Setup language servers.
vim.lsp.config('jedi_language_server', {})
vim.lsp.enable('jedi_language_server')

vim.lsp.config('ts_ls', {})
vim.lsp.enable('ts_ls')

vim.lsp.config('eslint', {})
vim.lsp.enable('eslint')

vim.lsp.config('rust_analyzer', {
  -- Server-specific settings. See `:help vim.lsp.config`
  settings = {
    ['rust-analyzer'] = {},
  },
})
vim.lsp.enable('rust_analyzer')

-- Drives lazydev.nvim (vim.* completion/hover while editing this config).
-- Skipped silently when lua-language-server is not installed.
vim.lsp.config('lua_ls', {})
vim.lsp.enable('lua_ls')

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end)
vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end)
-- vim.keymap.set('n', '<space>l', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<leader>td', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>cf', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})


-- The virtual text is annoying so hide it (eg with Pyright)
vim.diagnostic.config({
  virtual_text = false,
  -- signs = true,
  -- underline = true,
  -- update_in_insert = false,
  -- severity_sort = false,
})
