-- Installation required:
-- npm i -g pyright

-- Set <space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Install package manager
-- https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { import = 'plugins' },
})

-- Plugin specific setup
require('custom.telescope')
require('custom.set')
require('custom.experience')
require('custom.startify')

require('custom.ale')
require('custom.lsp')
require('custom.tree_sitter')
require('custom.cmp')

require('custom.test')

require('custom.autocmd')

require('custom.keymap')

vim.diagnostic.config{virual_text=false}
