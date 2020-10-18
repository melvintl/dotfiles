" Plugins
let need_to_install_plugins = 0
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    "autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
    let need_to_install_plugins = 1
endif

call plug#begin()

" Look and feel
Plug 'joshdick/onedark.vim'
Plug 'vim-airline/vim-airline'

" Experience + Functionality + Navigation
Plug 'tpope/vim-sensible'
Plug 'preservim/nerdtree'
Plug 'jistr/vim-nerdtree-tabs'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
" Dont really need all 3 - may decide to drop ctrlp?
Plug 'junegunn/fzf.vim'
Plug 'kien/ctrlp.vim'
Plug 'mileszs/ack.vim'

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'Xuyuanp/nerdtree-git-plugin'

" General dev/file type
Plug 'majutsushi/tagbar'
Plug 'tpope/vim-commentary'
Plug 'godlygeek/tabular'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'vim-test/vim-test'

" For Python/development
Plug 'w0rp/ale'
Plug 'pechorin/any-jump.vim'
Plug 'davidhalter/jedi-vim'
"Plug 'scrooloose/syntastic'
"Plug 'vim-scripts/indentpython.vim'

call plug#end()

if need_to_install_plugins == 1
    echo "Installing plugins..."
    silent! PlugInstall
    echo "Done!"
    q
endif

let g:any_jump_disable_default_keybindings = 1
let mapleader=" "
imap jk <Esc>
" map <M-a> <C-a>
" map <A-a> <C-a>

filetype plugin indent on
syntax on

set splitbelow splitright
set hidden

" always show the status bar
set laststatus=2

set t_Co=256
colorscheme onedark

set number relativenumber

" sane text files
set fileformat=unix
set encoding=utf-8
set fileencoding=utf-8

" sane editing
set tabstop=4
set shiftwidth=4
set softtabstop=4
set colorcolumn=80
set expandtab
set viminfo='25,\"50,n~/.viminfo

" code folding
set foldmethod=indent
set foldlevel=99

nmap <F2> :lopen<CR>
nmap <F3> :TagbarToggle<CR>

" word movement
imap <S-Left> <Esc>bi
nmap <S-Left> b
imap <S-Right> <Esc><Right>wi
nmap <S-Right> w

" indent/unindent
nmap <Tab> >>
imap <S-Tab> <Esc><<i
nmap <S-tab> <<

" mouse
set mouse=a
set ttymouse=xterm2
let g:is_mouse_enabled = 1
noremap <silent> <Leader>u :call ToggleMouse()<CR>
function ToggleMouse()
    if g:is_mouse_enabled == 1
        echo "Mouse OFF"
        set mouse=
        let g:is_mouse_enabled = 0
    else
        echo "Mouse ON"
        set mouse=a
        set ttymouse=xterm2
        let g:is_mouse_enabled = 1
    endif
endfunction

" wrap toggle
setlocal nowrap
noremap <silent> <Leader>p :call ToggleWrap()<CR>
function ToggleWrap()
    if &wrap
        echo "Wrap OFF"
        setlocal nowrap
        set virtualedit=all
        silent! nunmap <buffer> <Up>
        silent! nunmap <buffer> <Down>
        silent! nunmap <buffer> <Home>
        silent! nunmap <buffer> <End>
        silent! iunmap <buffer> <Up>
        silent! iunmap <buffer> <Down>
        silent! iunmap <buffer> <Home>
        silent! iunmap <buffer> <End>
    else
        echo "Wrap ON"
        setlocal wrap linebreak nolist
        set virtualedit=
        setlocal display+=lastline
        noremap  <buffer> <silent> <Up>   gk
        noremap  <buffer> <silent> <Down> gj
        noremap  <buffer> <silent> <Home> g<Home>
        noremap  <buffer> <silent> <End>  g<End>
        inoremap <buffer> <silent> <Up>   <C-o>gk
        inoremap <buffer> <silent> <Down> <C-o>gj
        inoremap <buffer> <silent> <Home> <C-o>g<Home>
        inoremap <buffer> <silent> <End>  <C-o>g<End>
    endif
endfunction

" Navigate splits
nmap <leader><Up> :wincmd k<CR>
nmap <leader><Down> :wincmd j<CR>
nmap <leader><Left> :wincmd h<CR>
nmap <leader><Right> :wincmd l<CR>
nmap <leader>k :wincmd k<CR>
nmap <leader>j :wincmd j<CR>
nmap <leader>h :wincmd h<CR>
nmap <leader>l :wincmd l<CR>

" " Quicker window movement
" nnoremap <C-j> <C-w>j
" nnoremap <C-k> <C-w>k
" nnoremap <C-h> <C-w>h
" nnoremap <C-l> <C-w>l

" All about the buffers!
nmap <leader>[ :bp!<CR>
nmap <leader>] :bn!<CR>
nmap <leader>x :bd<CR>
nmap <leader>q :bd<CR>
noremap <silent> <Leader>w :w<CR>
nnoremap <leader>b :CtrlPBuffer<CR>
" nnoremap <leader>b :Buffers<CR>
augroup termIgnore
    autocmd!
    autocmd TerminalOpen * set nobuflisted
augroup END
" Switch between the last two buffers
nnoremap <Leader><Leader> <C-^>

" Display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" restore place in file from previous session
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" NERDTree
let NERDTreeIgnore = ['\.pyc$', '__pycache__']
let NERDTreeMinimalUI = 1
let g:nerdtree_open = 0
map <leader>m :call NERDTreeToggle()<CR>
function NERDTreeToggle()
    NERDTreeTabsToggle
    if g:nerdtree_open == 1
        let g:nerdtree_open = 0
    else
        let g:nerdtree_open = 1
        wincmd p
    endif
endfunction

" Status line
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#ale#enabled = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" START: All the Search, CtrlP and FZF config
"
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~40%' }
" An action can be a reference to a function that processes selected lines
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

let g:fzf_action = {
  \ 'ctrl-q': function('s:build_quickfix_list'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }
let $FZF_DEFAULT_OPTS = '--bind ctrl-a:select-all'


if executable('ag')
  let g:ackprg = 'ag --vimgrep'

  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files.
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
endif

" " Issue on MacOS and Ack setting the below  as per https://github.com/mileszs/ack.vim/issues/18
function Search(string) abort
  let saved_shellpipe = &shellpipe
  let &shellpipe = '>'
  try
    execute 'Ack!' shellescape(a:string, 1)
  finally
    let &shellpipe = saved_shellpipe
  endtry
endfunction
nnoremap  <leader>f :call Search("")<left><left>
" nnoremap  <leader>f :Ag<CR>
" nnoremap  <C-f> :Rg<CR>

" END: ALL the search and FZF config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Change some of the clipboard settings
" On Debian OS first install gvim/ sudo apt-get install vim-gtk3 to get +clipboard in vim, on CentOS get vimx
"set clipboard=unnamedplus
set clipboard^=unnamed,unnamedplus
vmap <C-c> "+y
" map <C-p> "+p
vmap <C-c> "+y
vmap <C-x> "+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa


let g:ale_linters = {'python': ['pylint', 'flake8']}
let g:ale_fixers = {'python': ['reorder-python-imports', 'black']}
let g:ale_fix_on_save = 1
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
" let g:ale_set_quickfix = 1
let g:ale_set_loclist = 1

" Other shortcuts
nnoremap  <leader><CR> :term<CR>
nnoremap <C-j> :AnyJump<CR>





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" My main project/server specific shortcuts mapped here

" autocmd FileType python imap <F9> from ipdb import set_trace; set_trace()<Esc>:w<CR>:!clear;python %<CR>
autocmd FileType python imap <F9> from ipdb import set_trace; set_trace()<Esc>:w<CR>

imap <F10> <Esc>:w<CR>:!clear;make test_my<CR>
map <F10> :w<CR>:!clear;make test_my<CR>
" autocmd FileType python imap <F10> <Esc>:w<CR>:!clear;python %<CR>
" autocmd FileType python map <F10> :w<CR>:!clear;python %<CR>

autocmd FileType python imap <F11> <Esc>:w<CR>:terminal python %<CR>
autocmd FileType python map <F11> <CR>:terminal python %<CR>
imap <F12> <Esc>:w<CR>:!clear;make test<CR>
map <F12> :w<CR>:!clear;make test<CR>

" All things testing 
" nmap <silent> t<C-n> :TestNearest<CR>
nmap <silent> tf :TestFile<CR>
" nmap <silent> t<C-s> :TestSuite<CR>
nmap <silent> tl :TestLast<CR>
" nmap <silent> t<C-g> :TestVisit<CR>
