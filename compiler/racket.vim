if exists("current_compiler")
	finish
endif
let current_compiler = "raco"

let s:save_cpo = &cpo
set cpo&vim

CompilerSet errorformat&
set errorformat?
CompilerSet makeprg=raco\ exe\ %

let &cpo = s:save_cpo
unlet s:save_cpo
