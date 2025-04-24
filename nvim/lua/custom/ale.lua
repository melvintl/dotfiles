vim.g.ale_linters = {
  ["python"] = {"pylint", "flake8", "mypy"},
  ["typescript"] = {"eslint", "tsserver"},
  ["javascript"] = {"eslint"}
}
vim.g.ale_fixers = {
  ["python"] = {'reorder-python-imports', 'black'},
  ["typescript"] = {'eslint', 'prettier'},
  ["javascript"] = {'eslint', 'prettier'}
}
vim.g.ale_fix_on_save = 1
vim.g.ale_echo_msg_format = '[%linter%] %s [%severity%]'
vim.g.ale_set_loclist = 1

vim.g.ale_use_neovim_diagnostics_api = 1
