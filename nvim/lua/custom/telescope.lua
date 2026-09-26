require('telescope').setup({
  defaults = {},
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>f', '<cmd>Telescope find_files disable_devicons=true<CR>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>/', builtin.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>ht', builtin.help_tags, { desc = 'Help tags' })
