" :make checks the file being edited with Lean 4. Set by ftplugin/lean.vim.
" See |lean-make|.
if exists("current_compiler")
  finish
endif
let current_compiler = "lean"

let s:save_cpo = &cpo
set cpo&vim

" Inside a Lake project the file's imports only resolve through Lake, and
" "lake lean" builds them before it checks the file. Lake does not look for
" the project above the current directory, which follows the buffer (vimrc),
" so the root is found here and handed over with -d. The nearest lakefile
" wins: a dependency under .lake/packages is checked as its own project.
let s:root = ''
if !empty(expand('%'))
  for s:name in ['lakefile.lean', 'lakefile.toml']
    let s:found = findfile(s:name, escape(expand('%:p:h'), ' ,;') . ';')
    if !empty(s:found) && strlen(fnamemodify(s:found, ':p:h')) > strlen(s:root)
      let s:root = fnamemodify(s:found, ':p:h')
    endif
  endfor
  unlet! s:name s:found
endif
let s:root = substitute(s:root, '\\', '/', 'g')

" Read by lean#quickfix(), which runs after :make: Lake reports a failing
" import by its path from here.
let b:lean_root = s:root

" Quoted by hand, with forward slashes, for the reason compiler/matlab.vim
" gives: the same line has to suit cmd.exe and bash. Lean writes its messages
" to stdout, but Lake writes those of an import that failed to build to
" stderr, and 'shellpipe' is a bare ">" when Vim was started from bash. The
" parentheses, a group to cmd.exe and a subshell to bash, let the 2>&1 be
" written here whatever 'shellpipe' goes on to add.
if empty(s:root) || !executable('lake')
  let s:makeprg = 'lean "%:gs?\\?/?"'
else
  let s:makeprg = '(lake -d "' . s:root . '" lean "%:p:gs?\\?/?" 2>&1)'
endif
execute 'CompilerSet makeprg=' . escape(s:makeprg, ' \|"')

" Lean:  Foo.lean:3:23: error: unsolved goals
"        Foo.lean:1:25: error(lean.synthInstanceFailed): failed to ...
" Lake, for an import that did not build:
"        error: Foo/Basic.lean:1:15: Type mismatch
" Only the first line of a message makes an entry. The goals, hints and
" notes under it stay in the list as plain lines, one below the other as
" Lean laid them out, where joining them to the entry would run a goal
" state together into one line. #eval output is plain lines too.
CompilerSet errorformat=
  \%f:%l:%c:\ %trror:\ %m,
  \%f:%l:%c:\ %trror(%*[^)]):\ %m,
  \%f:%l:%c:\ %tarning:\ %m,
  \%f:%l:%c:\ %tarning(%*[^)]):\ %m,
  \%f:%l:%c:\ %tnfo:\ %m,
  \%trror:\ %f:%l:%c:\ %m,
  \%tarning:\ %f:%l:%c:\ %m,
  \%tnfo:\ %f:%l:%c:\ %m

unlet s:root s:makeprg
let &cpo = s:save_cpo
unlet s:save_cpo
