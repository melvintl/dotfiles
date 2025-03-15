local null_ls = require("null-ls")

source_list = {
  -- null_ls.builtins.formatting.stylua,
  -- null_ls.builtins.diagnostics.eslint,
  null_ls.builtins.completion.spell,
}


if vim.fn.executable('pylint') == 1 then
  table.insert(source_list, null_ls.builtins.diagnostics.pylint)
end

if vim.fn.executable('black') == 1 then
  table.insert(source_list, null_ls.builtins.formatting.black)
end

if vim.fn.executable('mypy') == 1 then
  table.insert(source_list, null_ls.builtins.diagnostics.mypy)
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
  sources = source_list,

  -- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Formatting-on-save
  -- you can reuse a shared lspconfig on_attach callback here
  on_attach = function(client, bufnr)
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          -- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
          -- on later neovim version, you should use vim.lsp.buf.format({ async = false }) instead
          vim.lsp.buf.format({ async = false }) 
          -- vim.lsp.buf.formatting_sync()
        end,
      })
    end
  end,
})

