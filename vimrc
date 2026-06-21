set nocompatible

if has('syntax') && !exists('g:syntax_on')
  syntax on
endif
filetype plugin indent on

if has('termguicolors')
  set termguicolors
endif

set ttimeout ttimeoutlen=100

augroup morning_colorscheme
  au!
  au Colorscheme morning highlight Constant 
   \ ctermfg=201 ctermbg=NONE guifg=#ff00ff guibg=NONE
augroup END

set autoindent smarttab
set incsearch hlsearch

" CTRL-L clears highlight of hlsearch
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :nohlsearch<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>
endif

set formatoptions+=jro/ncq
set formatoptions-=t
set textwidth=80
set autoread

set viminfo^=!
set sessionoptions-=options viewoptions-=options

if empty(mapcheck('<C-U>', 'i'))
  inoremap <C-U> <C-G>u<C-U>
endif

if empty(mapcheck('<C-W>', 'i'))
  inoremap <C-W> <C-G>u<C-W>
endif

" This disables netrw
let g:loaded_netrw=1
let g:loaded_netrwPlugin=1

" Remove included files from the search list
" to speed up insert mode completion problems.
"
" BUG: I still get infinite 'Scanning: <path>'
" on repeated i_CTRL-X_CTRL-L presses while
" holding down CTRL key. There is only one other
" person online who seems to have encountered
" this bug, but there was no progress in solving
" it so far as I can tell. Upon grepping vim
" source, I can find the location of the 'Scanning: '
" message. However, it led me no closer to figuring
" out this issue.
"
" NOTE: This behavior does not occur on posix.
" As expected, repeated presses of i_CTRL-X_CTRL-L
" bring in lines below matching line.
set complete-=i foldmethod=manual

" Faster grepping
if executable('rg')
  set grepprg=rg\ --vimgrep\ -uu
  set grepformat+=%f:%l:%c:%m
endif

" Open web links with lynx when it is available on everything except Windows
if executable('lynx') && !has('win32')
  let g:Openprg='lynx'
  nnoremap gx :execute '!lynx ' . shellescape(substitute(expand("<cfile>", 1), '#', '%23', 'g'))<CR><CR>
endif

set nrformats-=octal

if exists(":DiffOrig") != 2
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
endif

" From tpope/vim-sensible. Highlights $() in sh filetype.
if !exists('g:is_posix') && !exists('g:is_bash') && !exists('g:is_kornshell') && !exists('g:is_dash')
  let g:is_posix = 1
endif
