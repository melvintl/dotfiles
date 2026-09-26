vim.g.ale_linters = {
  ['python'] = { 'ruff', 'pylint', 'flake8', 'mypy' },
  ['typescript'] = { 'eslint' },
  ['javascript'] = { 'eslint' },
}
-- Language servers are run by vim.lsp.enable (lua/custom/lsp.lua). The default
-- "auto" only detects lspconfig's legacy setup(), so ALE would start a second
-- copy of each server.
vim.g.ale_disable_lsp = 1
vim.g.ale_fixers = {
  ['python'] = {
    'ruff',
    'reorder-python-imports',
    'ruff_format',
    -- 'black',  -- uncomment to use Black instead of ruff_format
  },
  ['typescript'] = { 'eslint', 'prettier' },
  ['javascript'] = { 'eslint', 'prettier' },
}
vim.g.ale_fix_on_save = 1
vim.g.ale_echo_msg_format = '[%linter%] %s [%severity%]'
vim.g.ale_set_loclist = 1

vim.g.ale_use_neovim_diagnostics_api = 1

-- Show ALE's virtual text on the cursor line only.
--
-- Why this wraps vim.diagnostic.set: after every lint, ALE's
-- lua/ale/diagnostics.lua calls vim.diagnostic.set(ns, buf, diags, opts) with
-- opts.virtual_text set to a plain boolean derived from ale_virtualtext_cursor
-- (true for 'current'/'all', false otherwise). Neovim stores that opts table
-- as the namespace config, so it overwrites the { current_line = true } set
-- below on the first lint. ALE has no setting that passes a table, hence the
-- wrapper strips the boolean for ALE's namespace only.
--
-- Breaks silently if ALE renames its 'ale' namespace (virtual text goes back
-- to every line); breaks loudly if vim.diagnostic.set changes signature.
-- Check both when updating either.
local ale_ns = vim.api.nvim_create_namespace('ale')
local diagnostic_set = vim.diagnostic.set
vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
  if namespace == ale_ns and opts then
    opts.virtual_text = nil
  end
  return diagnostic_set(namespace, bufnr, diagnostics, opts)
end
vim.diagnostic.config({ virtual_text = { current_line = true } }, ale_ns)
