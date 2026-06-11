set nocompatible

if has('syntax')
  syntax on
endif
filetype plugin on

if has('termguicolors')
  set termguicolors
endif

augroup morning_colorscheme
  au!
  au Colorscheme morning highlight Constant 
   \ ctermfg=201 ctermbg=NONE guifg=#ff00ff guibg=NONE
augroup END

if has('reltime')
  set incsearch
endif

let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1
