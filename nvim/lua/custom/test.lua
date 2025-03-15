local cmd = vim.cmd

cmd [[
" make test commands execute using vimux
let test#strategy = "vimux"

" I have projects where tests are written in pythons UnitTest
" but want to run the tests using pytest
let test#python#runner = 'pytest'
]]

vim.keymap.set('n', 'tt', '<cmd>TestFile <CR>')
vim.keymap.set('n', 'ts', '<cmd>TestSuite <CR>')
vim.keymap.set('n', 'tl', '<cmd>TestLast <CR>')
vim.keymap.set('n', 'tn', '<cmd>TestNearest <CR>')
