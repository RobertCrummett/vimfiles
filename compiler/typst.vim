if exists("current_compiler") | finish | endif
let current_compiler = "typst"

let s:save_cpo = &cpo
set cpo&vim

CompilerSet errorformat&
CompilerSet makeprg=typst\ compile\ --diagnostic-format\ short\ %:S\ $*

let &cpo = s:save_cpo
unlet s:save_cpo
