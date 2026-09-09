" :make runs the current file in the Matlab session matlabserver keeps warm,
" so it costs milliseconds rather than restarting Matlab. Set by
" after/ftplugin/matlab.vim; plugin/matlabserver.vim starts the session first
" if it is not up.
"
" 'makeprg' has to name a program, because :make goes through the shell and
" cannot speak to the socket itself, so it runs matlab/mlmake.py. That script
" only relays: server.m already reports errors as "file:line: message", the
" shape 'errorformat' reads below.
if exists("current_compiler")
  finish
endif
let current_compiler = "matlab"

let s:save_cpo = &cpo
set cpo&vim

" matlab/, two levels up from compiler/matlab.vim.
"
" Quoted by hand, with forward slashes, rather than through shellescape() and
" %:p:S. With 'shell' set to bash and 'shellslash' off, which is this setup,
" shellescape() reads the backslashes of a Windows path as escapes and drops
" them: shellescape('C:\a b\c.py') gives "C:a bc.py". Forward slashes suit
" Windows, bash and Matlab alike, and :gs converts the file name too.
let s:client = substitute(expand('<sfile>:p:h:h'), '\\', '/', 'g') . '/matlab/mlmake.py'
let s:python = get(g:, 'matlabserver_python', 'python')

execute 'CompilerSet makeprg='
  \ . escape(s:python . ' "' . s:client . '" "%:p:gs?\\?/?"', ' \|"')

" Anything that is not an error is Matlab's own output: shown by :make, kept
" out of the quickfix list. An error with no stack, from the command line
" rather than a file, still gets an entry so it is not silently dropped.
CompilerSet errorformat=%f:%l:\ %m,Error:\ %m,%-G%.%#

let &cpo = s:save_cpo
unlet s:save_cpo
