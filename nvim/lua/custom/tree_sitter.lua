-- nvim-treesitter `main` branch (the `master` branch is frozen and does not
-- support Neovim 0.12+). The plugin now only ships parsers and queries;
-- highlighting, indentation and folding come from Neovim itself.
local ts = require('nvim-treesitter')
ts.setup {
  -- Parsers and queries land here, prepended to 'runtimepath'.
  install_dir = vim.fn.stdpath('data') .. '/site',
}
-- Replaces the old `ensure_installed`. Asynchronous, and a no-op once the
-- parsers are present. Use `:TSUpdate` to refresh them.
ts.install {
  'c',
  'cpp',
  'go',
  'lua',
  'python',
  'rust',
  'tsx',
  'typescript',
  'vimdoc',
  'vim',
}
-- Replaces `highlight = { enable = true }` and `indent = { enable = true }`.
-- Applies to any filetype with an available parser, which is what the old
-- module-based config did.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom_treesitter', { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if not lang or not pcall(vim.treesitter.start, args.buf, lang) then
      return
    end
    -- Treesitter indentation is still flagged experimental upstream, so only
    -- take it over from the filetype plugin where a query actually exists.
    if vim.treesitter.query.get(lang, 'indents') then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
