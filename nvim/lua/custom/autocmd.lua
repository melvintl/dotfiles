local api = vim.api
local cmd = vim.cmd

-- go to last loc when opening a buffer
api.nvim_create_autocmd(
    "BufReadPost",
    { command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]] }
)

cmd [[
augroup run_buffer
    autocmd FileType python map <buffer> <Leader>x :call VimuxRunCommand("clear;python " . bufname("%"))<CR>
    autocmd FileType python let b:dispatch = 'python %'

    autocmd FileType python map <buffer> <F8> :!clear; python %<CR>
    autocmd FileType python imap <buffer> <F8> <Esc>:w<CR>:!clear; python %<CR>

    autocmd FileType python imap <buffer> <F9> from ipdb import set_trace; set_trace()<Esc>:w<CR>
augroup END

" TDD for python/pytest
imap <F10> <Esc>:wa<CR>:!clear;python -m pytest tests/ -s --pdb -o log_cli=True -p no:warnings --picked<CR>
map <F10> :wa<CR>:!clear;python -m pytest -s tests/ --pdb -o log_cli=True -p no:warnings --picked<CR>

imap <F12> <Esc>:wa<CR>:!clear;python -m pytest tests/ -s --pdb -o log_cli=True -p no:warnings --testmon<CR>
map <F12> :wa<CR>:!clear;python -m pytest -s tests/ --pdb -o log_cli=True -p no:warnings --testmon<CR>


nmap <F4> :lopen<CR>
imap <F5> <Esc>:w<CR>:Dispatch<CR>
map <F5> :w<CR>:Dispatch<CR>
" Get rid of the annoying diagnostic from Pyright
nmap <F6> :lua vim.diagnostic.hide()<CR>
]]
