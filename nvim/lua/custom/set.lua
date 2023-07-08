
-- dont need the annoying .swp and and ~backup files
vim.o.noswapfile = true
vim.o.nobackup = true

vim.o.splitbelow = true
vim.o.splitright = true
vim.o.hidden = true


-- tabs and columns
-- vim.o.tabstop=4
-- vim.o.shiftwidth=4
-- vim.o.softtabstop=4
-- vim.o.colorcolumn=80
-- vim.o.expandtab = true


-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true
vim.wo.relativenumber = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

vim.cmd [[
  command Q :qa!
  command W :w!
]]
