" vim:fdm=marker

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Melvins .vimrc file. Turn vim into an IDE (optimised for Python)
"
" Objectives of the .virmrc:
"  - Minimal external installations outside of the vim plugins
"  - Go anywhere. Do anything: Works on MacOS, Debian, CentOS (& Amazon Linux)
"
" Note for mappings:
"  - Consider mapping Caps lock to Ctrl in the OS """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let mapleader=" "

" plugins  {{{
let first_time_install_plugins = 0
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    "autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
    let first_time_install_plugins = 1
endif

call plug#begin()

" Look and feel
Plug 'joshdick/onedark.vim'
" Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Functionality + Navigation
Plug 'mhinz/vim-startify'           " on start page navigation
Plug 'tpope/vim-sensible'           " sensible defaults for less cluttered vimrc
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
" Dont really need all 3 - may decide to drop ctrlp. fzf > ctrlp + ack
Plug 'junegunn/fzf.vim'             " optional external dependency on ag, ripgrep, bat
Plug 'kien/ctrlp.vim'
Plug 'mileszs/ack.vim'
Plug 'majutsushi/tagbar'            " external install dependency
Plug 'simnalamburt/vim-mundo'       " keep undoing with a visual tree
Plug 'justinmk/vim-sneak'           " prefer sneak over vim-easymotion
Plug 'junegunn/vim-peekaboo'
" Plug 'liuchengxu/vim-which-key'

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'Xuyuanp/nerdtree-git-plugin'

" General file-type/dev support
Plug 'yggdroot/indentline'
Plug 'tpope/vim-commentary'
Plug 'godlygeek/tabular'            " simplify tabular formating
Plug 'chrisbra/csv.vim'             " simple csv viewer/analyzer in vim
" Plug 'sheerun/vim-polyglot'

" For Python/development and testing
Plug 'w0rp/ale'
Plug 'davidhalter/jedi-vim'         " python autocomplete and fast navigation
Plug 'vim-test/vim-test'            " TDD stuff

" tmux,  job dispatch, REPL
" Plug 'edkolev/tmuxline.vim'           " if you dont have an existing tmux theme
Plug 'christoomey/vim-tmux-navigator'
Plug 'benmills/vimux'
Plug 'tpope/vim-dispatch'
Plug 'jpalardy/vim-slime'
Plug 'wellle/tmux-complete.vim'
" Plug 'metakirby5/codi.vim'          " Works better on Neovim

call plug#end()

if first_time_install_plugins == 1
    echo "Installing plugins..."
    silent! PlugInstall
    echo "...Install complete"
    q
endif
" }}}

" settings (general) {{{
filetype plugin indent on
syntax on

" dont need the annoying .swp and and ~backup files
set noswapfile
set nobackup

set number relativenumber               " line numbers - best of both worlds

" search settings
set ignorecase
set smartcase
set hlsearch

set splitbelow splitright
set hidden

set laststatus=2                         " always show the status bar

" file format and encoding
set fileformat=unix
set encoding=utf-8
set fileencoding=utf-8

" tabs and columns
set tabstop=4
set shiftwidth=4
set softtabstop=4
set colorcolumn=80
set expandtab


 " restore place in file from previous session
set viminfo='25,\"50,n~/.viminfo
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" code folding
set foldmethod=indent
set foldlevel=99

" display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" enable persistent undo so that undo history persists across vim sessions
if !isdirectory($HOME."/.vim")
    call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undo")
    call mkdir($HOME."/.vim/undo", "", 0700)
endif
set undodir=~/.vim/undo
set undofile
" }}}

" alias {{{
command Q :qa!
command W :w!

" }}}

" color my world! {{{
if (has("termguicolors"))
    set termguicolors     " Enable true colors if available
    colorscheme onedark
    " set background=dark
    " colorscheme gruvbox

    " highlight Comment cterm=italic gui=italic
    set cursorline
    " Highlight current line
    autocmd ColorScheme * highlight StatusLine ctermbg=darkgray cterm=NONE guibg=darkgray gui=NONE
else
    set t_Co=256
    colorscheme onedark
endif
" }}}

" general mapping & navigation mappings {{{
imap jk <Esc>
nmap <F2> :lopen<CR>
nnoremap  <leader><CR> :term<CR>

" clear highlighted text, i tend to use / to search often
nmap \ :noh<CR>

" word movement
imap <S-Left> <Esc>bi
nmap <S-Left> b
imap <S-Right> <Esc><Right>wi
nmap <S-Right> w

" indent/unindent
nmap <Tab> >>
imap <S-Tab> <Esc><<i
nmap <S-tab> <<

" navigate splits
nmap <leader><Up> :wincmd k<CR>
nmap <leader><Down> :wincmd j<CR>
nmap <leader><Left> :wincmd h<CR>
nmap <leader><Right> :wincmd l<CR>
nmap <leader>k :wincmd k<CR>
nmap <leader>j :wincmd j<CR>
nmap <leader>h :wincmd h<CR>
nmap <leader>l :wincmd l<CR>

" Quicker window movement
" nnoremap <C-j> <C-w>j
" nnoremap <C-k> <C-w>k
" nnoremap <C-h> <C-w>h
" nnoremap <C-l> <C-w>l
" }}}

" session {{{
" noremap <silent> <Leader>sr :source ~/.vim/Session.vim<CR>
noremap <silent> <Leader>ss :call SaveSession()<CR>
function! SaveSession()
    NERDTreeClose
    MundoHide
    " mks! ~/.vim/Session.vim
    SSave
endfunction
" }}}

" mouse {{{
set mouse=a
"Mouse may not work to resize windows etc on remote server
set ttymouse=xterm2

let g:is_mouse_enabled = 1
noremap <silent> <Leader>o :call ToggleMouse()<CR>
function! ToggleMouse()
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
" }}}

" wrap toggle {{{
setlocal nowrap
noremap <silent> <Leader>p :call ToggleWrap()<CR>
function! ToggleWrap()
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
" }}}

" clipboard {{{
" Change some of the clipboard settings
" On Debian OS first install gvim/ sudo apt-get install vim-gtk3 to get +clipboard in vim
" on CentOS get vim-X11 for vimx
"set clipboard=unnamedplus
set clipboard^=unnamed,unnamedplus
vmap <C-c> "+y
" map <C-p> "+p
vmap <C-c> "+y
vmap <C-x> "+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa
" }}}

" buffers mapping {{{
"
" " Cycle through buffers
" nmap <leader>[ :bp!<CR>
" nmap <leader>] :bn!<CR>

nmap <leader>q :bd<CR>
noremap <silent> <Leader>w :w!<CR>
" Use CtrlP plugin
nnoremap <leader>b :CtrlPBuffer<CR>
" " Use FZF plugin
" nnoremap <leader>b :Buffers<CR>

" " Make sure that terminal is not added to buffer when cyclying through buffers
" augroup term_ignore
"     autocmd!
"     autocmd TerminalOpen * set nobuflisted
" augroup END

" Switch between the last two buffers
nnoremap <Leader><Leader> <C-^>
" }}}

" plugin NERDTree {{{
let NERDTreeIgnore = ['\.pyc$', '__pycache__']
let NERDTreeMinimalUI = 1
map <leader>m : NERDTreeToggle<CR>
" }}}

" plugin airline {{{
" let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#buffer_nr_show = 1
" let g:airline#extensions#tabline#fnamemod = ':t'  " show only filename
let g:airline#extensions#ale#enabled = 1
" }}}

" plugin search, CtrlP, FZF  {{{
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" Default fzf layout
" - down / up / left / right
" let g:fzf_layout = { 'down': '~40%' }
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

" Issue on MacOS and Ack setting the below as per https://github.com/mileszs/ack.vim/issues/18
function! Search(string) abort
  let saved_shellpipe = &shellpipe
  let &shellpipe = '>'
  try
    execute 'Ack!' shellescape(a:string, 1)
  finally
    let &shellpipe = saved_shellpipe
  endtry
endfunction

nnoremap  <leader>f :Files<CR>
nnoremap  <leader>F :History<CR>

nnoremap  <leader>/ :call Search("")<left><left>
" nnoremap  <leader>/ :Ag<CR>

" Use Ctrl-/ to search in buffers
noremap <C-_> :BLines<space>
inoremap <C-_> <esc>:BLines<space>

" Insert mode completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-l> <plug>(fzf-complete-line)

" }}}

" plugin tagbar {{{
let g:tagbar_autoclose = 0
let g:tagbar_autofocus = 1
let g:tagbar_compact = 1
let g:tagbar_sort = 0       "sort as  per code in the file and not alphabetical
nmap <F3> :TagbarToggle<CR>
" }}}

" plugin ale {{{
let g:ale_linters = {'python': ['pylint', 'flake8']}
let g:ale_fixers = {'python': ['reorder-python-imports', 'black']}
let g:ale_fix_on_save = 1
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
" let g:ale_set_quickfix = 1
let g:ale_set_loclist = 1
" }}}

" plugin vim-gitgutter {{{
" Disabling the git gutter default mapping keys as the default maps to
" <leader>h<other-key> and slows my navigation mapping so disabling default
let g:gitgutter_map_keys = 0
set updatetime=100
nmap ]g <Plug>(GitGutterNextHunk)
nmap [g <Plug>(GitGutterPrevHunk)
" nmap <Leader>ga <Plug>(GitGutterStageHunk)
" }}}

" plugin vim-startify {{{
" handle cwd when opening a file through startify
let g:startify_change_to_dir = 0
let g:startify_change_to_vcs_root = 1
" Use :SS to save a session
let g:startify_session_persistence = 1
let g:startify_list_order = ['sessions', 'dir']
let g:startify_files_number = 5
let g:startify_list_order = [
            \ ['   Sessions'],
            \ 'sessions',
            \ ['   Recent Files'],
            \ 'dir',
            \ ]
" }}}



" plugin jedi-vim {{{
let g:jedi#popup_on_dot = 0
let g:jedi#goto_stubs_command = ""
" }}}

" plugin vim-test {{{
" make test commands execute using vimux
let test#strategy = "vimux"
" let test#strategy = "dispatch"

" I have projects where tests are written in pythons UnitTest
" but want to run the tests using pytest
let test#python#runner = 'pytest'

nmap <silent> tt :TestFile<CR>
nmap <silent> ts :TestSuite<CR>
nmap <silent> tl :TestLast<CR>
" }}}

" plugin vimux {{{
map <Leader>vr :call VimuxRunCommand("clear; python -m pytest .")<CR>
map <Leader>vp :VimuxPromptCommand<CR>
map <Leader>vl :VimuxRunLastCommand<CR>
map <Leader>vi :VimuxInspectRunner<CR>
map <Leader>vq :VimuxCloseRunner<CR>
map <Leader>vx :VimuxInterruptRunner<CR>
map <Leader>vz :call VimuxZoomRunner()<CR>
" }}}

"plugin tmuxline {{{
let g:tmuxline_powerline_separators = 0
let g:tmuxline_preset = {
      \'a'    : '#S',
      \'b'    : '#I #W',
      \'c'    : '',
      \'win'  : '#I #W',
      \'cwin' : '#I #W',
      \'x'    : '%a',
      \'y'    : '%R',
      \'z'    : ''}
" }}}

" plugin slime {{{
let g:slime_target = "tmux"
let g:slime_default_config = {"socket_name": get(split($TMUX, ","), 0), "target_pane": ":.2"}
let g:slime_cell_delimiter = "#%%"      "setup like ipython notebook cell
nmap <leader>s <Plug>SlimeSendCell

" }}}

" plugin tmuxcomplete {{{
let g:tmuxcomplete#trigger = 'completefunc'

let g:tmuxcomplete#asyncomplete_source_options = {
            \ 'name':      'tmuxcomplete',
            \ 'whitelist': ['*'],
            \ 'config': {
            \     'splitmode':      'lines,words',
            \     'filter_prefix':   1,
            \     'show_incomplete': 1,
            \     'sort_candidates': 0,
            \     'scrollback':      0,
            \     'truncate':        0
            \     }
            \ }

" }}}

" csv plugins {{{
augroup filetype_csv_detect
      au! BufRead,BufNewFile *.csv,*.dat    setfiletype csv
augroup END

" auto highlight current column
let g:csv_highlight_column = 'y'

" scan only fist few lines to determine the delimeter
let g:csv_start = 1
let g:csv_end = 100

" run command: NewDelimiter <> in case of different delimiter
let g:csv_delim_test = ',;'

" Instead of manually running %ArrangeColumn every time 
" automatically do it for small files
let g:csv_autocmd_arrange      = 1
let g:csv_autocmd_arrange_size = 1024*1024

" }}}

" other plugins {{{
let g:mundo_right = 1
let g:sneak#label = 1
let g:peekaboo_delay = 1000         "if i dont know which reg to paste from then show popup after delay

" }}}

" python: project specific mapping {{{
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

augroup run_buffer
    autocmd FileType python map <buffer> <Leader>x :call VimuxRunCommand("clear;python " . bufname("%"))<CR>
    autocmd FileType python let b:dispatch = 'python %'

    " autocmd FileType python map <buffer> <F7> :terminal python %<CR>
    autocmd FileType python map <buffer> <F8> :!clear; python %<CR>
    autocmd FileType python imap <buffer> <F8> <Esc>:w<CR>:!clear; python %<CR>

    " autocmd FileType python imap <F9> from ipdb import set_trace; set_trace()<Esc>:w<CR>:!clear;python %<CR>
    autocmd FileType python imap <buffer> <F9> from ipdb import set_trace; set_trace()<Esc>:w<CR>
augroup END

imap <F5> <Esc>:w<CR>:Dispatch<CR>
map <F5> :w<CR>:Dispatch<CR>

" run make commands
imap <F10> <Esc>:wa<CR>:!clear;make test_my<CR>
map <F10> :wa<CR>:!clear;make test_my<CR>

imap <F12> <Esc>:wa<CR>:!clear;make test<CR>
map <F12> :wa<CR>:!clear;make test<CR>

" }}}
