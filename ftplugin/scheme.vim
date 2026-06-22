if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

compiler racket

setlocal autoindent
setlocal lisp
setlocal lispwords+=cond
setlocal syntax=racket

augroup racket_syntax_for_scheme_files
  au!
  au Filetype scheme setlocal syntax=racket
augroup END
