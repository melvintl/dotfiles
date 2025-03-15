-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

require('telescope').setup{
  defaults = {}
}

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>f', '<cmd>Telescope find_files disable_devicons=true<CR>', {})
vim.keymap.set('n', '<leader>/', builtin.live_grep, {})
vim.keymap.set('n', '<leader>b', builtin.buffers, {})
vim.keymap.set('n', '<leader>ht', builtin.help_tags, {})
