if &compatible
  set nocompatible
endif

if has('syntax') && !exists('g:syntax_on')
  syntax on
endif
filetype plugin indent on

if has('termguicolors')
  set termguicolors
endif

set timeout timeoutlen=3000 ttimeoutlen=100

augroup colorscheme_modifications
  au!
  " colorscheme morning
  au Colorscheme morning highlight Constant ctermfg=201 ctermbg=NONE guifg=#ff00ff guibg=NONE

  " colorscheme evening
  au Colorscheme evening highlight Normal ctermbg=0 guibg=#000000
  au Colorscheme evening highlight EndOfBuffer ctermfg=153 ctermbg=0 guifg=#add8e6 guibg=#000000
augroup END

if has('extra_search')
  set hlsearch incsearch
endif
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :noh<C-R>=has('diff')?'<Bar>dif':''<CR><CR><C-L>
endif

set autoindent smarttab
set formatoptions+=jr/ncq fo-=to textwidth=80 nojoinspaces
nnoremap Q gq

set autoread
set viminfo^=!
if has('mksession')
  set sessionoptions-=options viewoptions-=options
endif

if empty(mapcheck('<C-U>', 'i'))
  inoremap <C-U> <C-G>u<C-U>
endif

if empty(mapcheck('<C-W>', 'i'))
  inoremap <C-W> <C-G>u<C-W>
endif

" This disables netrw
let g:loaded_netrw=1
let g:loaded_netrwPlugin=1

" Remove included files from the search list to speed up insert mode completion
" problems.
"
" BUG: I still get infinite 'Scanning: <path>' on repeated i_CTRL-X_CTRL-L
" presses while holding down CTRL key. There is only one other person online who
" seems to have encountered this bug, but there was no progress in solving it so
" far as I can tell. Upon grepping vim source, I can find the location of the
" 'Scanning: ' message. However, it led me no closer to figuring out this issue.
"
" NOTE: This behavior does not occur on posix systems. As expected, repeated
" presses of i_CTRL-X_CTRL-L bring in lines below matching line.
set complete-=i foldmethod=manual

if executable('rg')
  set grepprg=rg\ --vimgrep\ -uu
  set grepformat+=%f:%l:%c:%m
endif

if executable('lynx') && !has('win32')
  let g:Openprg='lynx'
  nnoremap gx :execute '!lynx ' . shellescape(substitute(expand("<cfile>", 1), '#', '%23', 'g'))<CR><CR>
endif

set nrformats-=octal

if exists(":DiffOrig") != 2
  com DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | difft | wincmd p | difft
endif

" From tpope/vim-sensible. Highlights $() in sh filetype.
if !exists('g:is_posix') && !exists('g:is_bash') && !exists('g:is_kornshell') && !exists('g:is_dash')
  let g:is_posix = 1
endif
