if exists("current_compiler")
  finish
endif
let current_compiler = "racket"

let s:save_cpo = &cpo
set cpo&vim

CompilerSet errorformat&
CompilerSet makeprg=raco\ make\ %

let &cpo = s:save_cpo
unlet s:save_cpo
