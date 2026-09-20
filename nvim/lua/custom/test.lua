-- make test commands execute using vimux
vim.g['test#strategy'] = 'vimux'

-- I have projects where tests are written with Python's unittest
-- but want to run them using pytest
vim.g['test#python#runner'] = 'pytest'

vim.keymap.set('n', '<leader>tt', '<cmd>TestFile<CR>', { desc = 'Test file' })
vim.keymap.set('n', '<leader>ts', '<cmd>TestSuite<CR>', { desc = 'Test suite' })
vim.keymap.set('n', '<leader>tl', '<cmd>TestLast<CR>', { desc = 'Test last' })
vim.keymap.set('n', '<leader>tn', '<cmd>TestNearest<CR>', { desc = 'Test nearest' })
