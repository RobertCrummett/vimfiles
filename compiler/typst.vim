if exists("current_compiler")
  finish
endif
let current_compiler = "typst"

let s:save_cpo = &cpo
set cpo&vim

CompilerSet errorformat&
" Typst names a file by its canonical path, which on Windows is the verbatim
" form \\?\C:\dir\file.typ. Vim tells buffers apart by name there, so a jump
" to that name opens a second buffer on the file being edited, and the ? in
" it is a wildcard to :edit. This entry reads the \\?\ and leaves it out of
" %f. A drive letter has to follow: \\?\UNC\server\share is a network path,
" and is not a path without its prefix.
CompilerSet errorformat^=%\\%\\%\\%\\?%\\%\\%\\%%(%\\a:%\\)%\\@=%f:%l:%c:%m
CompilerSet makeprg=typst\ compile\ --diagnostic-format\ short\ %

let &cpo = s:save_cpo
unlet s:save_cpo
