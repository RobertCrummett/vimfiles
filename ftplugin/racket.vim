if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

compiler racket

setlocal autoindent
setlocal lisp
setlocal lispwords+=cond

inoremap <buffer> ( ()<esc>i
inoremap <buffer> ) ()<esc>i

inoremap <buffer> <silent> <expr> <BS>  
  \ (col('.') > 1 && getline('.')[col('.') - 2] =~# '[()]')
  \ ? "\<ESC>:call parens#DeleteParens()\<CR>"
  \ : "\<BS>"

inoremap <buffer> <silent> <expr> <C-h> 
  \ (col('.') > 1 && getline('.')[col('.') - 2] =~# '[()]')
  \ ? "\<ESC>:call parens#DeleteParens()\<CR>"
  \ : "\<C-h>"
