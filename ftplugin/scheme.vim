if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal autoindent
setlocal lisp
setlocal lispwords+=cond
setlocal syntax=racket
