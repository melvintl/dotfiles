-- Setup language servers.
vim.lsp.config('jedi_language_server', {})
vim.lsp.enable('jedi_language_server')

vim.lsp.config('ts_ls', {})
vim.lsp.enable('ts_ls')

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
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, { desc = 'Diagnostic float' })
vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = 'Previous diagnostic' })
vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = 'Next diagnostic' })
-- vim.keymap.set('n', '<space>l', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local function opts(desc)
      return { buffer = ev.buf, desc = desc }
    end
    -- Built-in completion (replaces nvim-cmp). Autotrigger only fires on the
    -- server's trigger characters (`.`, `:`), so add identifier characters to
    -- get the popup while typing a name, as cmp did.
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method('textDocument/completion') then
      local provider = client.server_capabilities.completionProvider
      local chars = vim.list_extend({}, provider.triggerCharacters or {})
      for _, c in ipairs(vim.split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_', '')) do
        table.insert(chars, c)
      end
      provider.triggerCharacters = chars
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts('LSP declaration'))
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts('LSP definition'))
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts('LSP implementation'))
    -- Nvim only maps <C-s> to signature help in insert/select mode by default.
    -- Servers only answer signature help between the call's parentheses, so
    -- fall back to hover when the cursor is on the name instead.
    vim.keymap.set('n', '<C-s>', function()
      vim.lsp.buf_request_all(ev.buf, 'textDocument/signatureHelp', function(client)
        return vim.lsp.util.make_position_params(0, client.offset_encoding)
      end, function(results)
        for _, response in pairs(results) do
          local result = response.result
          if result and result.signatures and #result.signatures > 0 then
            return vim.lsp.buf.signature_help()
          end
        end
        vim.lsp.buf.hover()
      end)
    end, opts('LSP signature help or hover'))
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts('LSP rename'))
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts('Code action'))
    vim.keymap.set('n', '<leader>cf', function()
      vim.lsp.buf.format({ async = true })
    end, opts('Format buffer'))
  end,
})

-- The virtual text is annoying so hide it
vim.diagnostic.config({
  virtual_text = false,
  -- signs = true,
  -- underline = true,
  -- update_in_insert = false,
  -- severity_sort = false,
})
