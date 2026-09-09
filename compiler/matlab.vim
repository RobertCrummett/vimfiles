" 'errorformat' for the file:line: message lines matlab/server.m reports, and
" a 'makeprg' that runs a file without needing a session.
"
" The fast path does not come through here. Typing :make in a Matlab buffer
" runs :MatlabMake, which sends the file down the socket to the warm session
" and reads the reply with :cgetexpr, in Vimscript, with nothing to install.
" 'makeprg' is what a :make from a script or a mapping falls back to, and what
" runs when the abbreviation is turned off: correct, needing no session, and
" paying Matlab's five second startup every time.
"
" Set by after/ftplugin/matlab.vim. See |matlabserver-make|.
if exists("current_compiler")
  finish
endif
let current_compiler = "matlab"

let s:save_cpo = &cpo
set cpo&vim

" Quoted by hand, with forward slashes, rather than through shellescape() and
" %:p:S. With 'shell' set to bash and 'shellslash' off, which is this setup,
" shellescape() reads the backslashes of a Windows path as escapes and drops
" them: shellescape('C:\a b\c.py') gives "C:a bc.py". Forward slashes suit
" Windows, bash and Matlab alike, and :gs converts the file name too.
let s:matlab = get(g:, 'matlabdoc_program', '')
if empty(s:matlab)
  let s:matlab = exepath('matlab')
endif
if empty(s:matlab)
  let s:found = sort(glob('C:/Program Files/MATLAB/R*/bin/matlab.exe', 0, 1))
  let s:matlab = empty(s:found) ? 'matlab' : s:found[-1]
  unlet s:found
endif
let s:matlab = substitute(s:matlab, '\\', '/', 'g')

execute 'CompilerSet makeprg='
  \ . escape('"' . s:matlab . '" -batch "cd(''%:p:h:gs?\\?/?''); %:t:r"', ' \|"')

" Runtime errors come as file:line: message, parse errors (which server.m
" resolves from Matlab's "File: x.m Line: 2 Column: 5" wording) with the
" column as well. Anything that is not an error is Matlab's own output:
" shown by :make, kept out of :clist. An error with no stack at all, raised
" from the command line rather than inside a file, still gets an entry, but
" Vim marks an entry with no file and no line invalid, so :clist hides it
" (:clist! shows it) and :MatlabMake falls back to the output window.
CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m,Error:\ %m,%-G%.%#

unlet s:matlab
let &cpo = s:save_cpo
unlet s:save_cpo
