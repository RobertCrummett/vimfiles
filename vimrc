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

" Remove included files from the search list
" to speed up insert mode completion problems.
"
" TODO I still get infinite 'Scanning: <path>'
" on repeated i_CTRL-X_CTRL-L presses while
" holding down CTRL key. There is only one other
" person online who seems to have encountered
" this bug, but there was no progress in solving
" it so far as I can tell. Upon grepping vim
" source, I can find the location of the 'Scanning: '
" message. However, it led me no closer to figuring
" out this issue.
set complete-=i
set foldmethod=manual

if executable('rg')
  set grepprg=rg\ --vimgrep\ -uu
  set grepformat+=%f:%l:%c:%m
endif
