if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal autoindent
setlocal lisp
setlocal lispwords+=cond

augroup RacketSyntaxForSchemeFiles
  au!
  au Filetype scheme setlocal syntax=racket
augroup END
