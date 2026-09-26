local api = vim.api

-- go to last loc when opening a buffer
api.nvim_create_autocmd('BufReadPost', {
  group = api.nvim_create_augroup('last_loc', { clear = true }),
  command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]],
})

-- Python: run the current file
api.nvim_create_autocmd('FileType', {
  group = api.nvim_create_augroup('run_buffer', { clear = true }),
  pattern = 'python',
  callback = function(ev)
    local function opts(desc)
      return { buffer = ev.buf, desc = desc }
    end
    vim.b[ev.buf].dispatch = 'python %'
    vim.keymap.set(
      'n',
      '<Leader>x',
      ':call VimuxRunCommand("clear;python " . bufname("%"))<CR>',
      opts('Run file in vimux')
    )
    vim.keymap.set('n', '<F8>', ':!clear; python %<CR>', opts('Run file'))
    vim.keymap.set('i', '<F8>', '<Esc>:w<CR>:!clear; python %<CR>', opts('Write and run file'))
    vim.keymap.set('i', '<F9>', 'from ipdb import set_trace; set_trace()<Esc>:w<CR>', opts('Insert ipdb breakpoint'))
  end,
})

-- TDD for python/pytest
-- imap <F10> <Esc>:wa<CR>:!clear;python -m pytest tests/ -s --pdb -o log_cli=True -p no:warnings --picked<CR>
-- map <F10> :wa<CR>:!clear;python -m pytest -s tests/ --pdb -o log_cli=True -p no:warnings --picked<CR>

-- imap <F12> <Esc>:wa<CR>:!clear;python -m pytest tests/ -s --pdb -o log_cli=True -p no:warnings --testmon<CR>
-- map <F12> :wa<CR>:!clear;python -m pytest -s tests/ --pdb -o log_cli=True -p no:warnings --testmon<CR>

vim.keymap.set('n', '<F4>', ':lopen<CR>', { desc = 'Open location list' })
vim.keymap.set('i', '<F11>', '<Esc>:w<CR>:Dispatch<CR>', { desc = 'Write and dispatch' })
vim.keymap.set('n', '<F11>', ':w<CR>:Dispatch<CR>', { desc = 'Write and dispatch' })
vim.keymap.set('n', '<F6>', vim.diagnostic.hide, { desc = 'Hide diagnostics' })
