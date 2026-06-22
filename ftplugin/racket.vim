if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

compiler racket

setlocal autoindent
setlocal lisp
setlocal lispwords+=cond
