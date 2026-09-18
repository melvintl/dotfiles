vim.g.ale_linters = {
  ["python"] = {"ruff", "pylint", "flake8", "mypy"},
  ["typescript"] = {"eslint"},
  ["javascript"] = {"eslint"}
}
-- Language servers are run by vim.lsp.enable (lua/custom/lsp.lua). The default
-- "auto" only detects lspconfig's legacy setup(), so ALE would start a second
-- copy of each server.
vim.g.ale_disable_lsp = 1
vim.g.ale_fixers = {
  ["python"] = {
    'ruff',
    'reorder-python-imports',
    'ruff_format',
    -- 'black',  -- uncomment to use Black instead of ruff_format
  },
  ["typescript"] = {'eslint', 'prettier'},
  ["javascript"] = {'eslint', 'prettier'}
}
vim.g.ale_fix_on_save = 1
vim.g.ale_echo_msg_format = '[%linter%] %s [%severity%]'
vim.g.ale_set_loclist = 1

vim.g.ale_use_neovim_diagnostics_api = 1

-- Show ALE's virtual text on the cursor line only. Through the diagnostics API
-- ALE turns ale_virtualtext_cursor = 'current' into virtual_text = true (every
-- line) and passes it to vim.diagnostic.set, which beats vim.diagnostic.config.
-- Drop that override so the namespace config below applies instead.
local ale_ns = vim.api.nvim_create_namespace('ale')
local diagnostic_set = vim.diagnostic.set
vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
  if namespace == ale_ns and opts then
    opts.virtual_text = nil
  end
  return diagnostic_set(namespace, bufnr, diagnostics, opts)
end
vim.diagnostic.config({ virtual_text = { current_line = true } }, ale_ns)
