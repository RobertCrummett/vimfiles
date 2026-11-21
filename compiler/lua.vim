" :make runs the file with Lua, and its error and the traceback under it
" land in the quickfix list. Set by after/ftplugin/lua.vim.
"
" It runs from the buffer's directory, which the vimrc keeps the current one,
" so that require finds the modules beside the file.
if exists("current_compiler")
  finish
endif
let current_compiler = "lua"

let s:save_cpo = &cpo
set cpo&vim

" Quoted by hand, with forward slashes, for the reason compiler/matlab.vim
" gives: the same line has to suit cmd.exe and bash.
execute 'CompilerSet makeprg=' . escape('lua "%:gs?\\?/?"', ' \|"')

" lua: runtime.lua:2: attempt to index a nil value (field 'x')
" stack traceback:
"         runtime.lua:2: in function <runtime.lua:1>
"         (...tail calls...)
"         runtime.lua:8: in main chunk
"         [C]: in ?
" Lua names itself as it was started: "lua" from cmd.exe, its whole path
" from bash, C:\...\bin\lua.exe, whose drive letter is no file name. The
" error makes an entry, and so does each frame in a file, innermost first, so
" :cnext walks out of the stack. The header, the frames of C functions and
" the tail calls are left out. What the program prints, and the list of
" places require looked in, stay as plain lines, which :copen shows.
CompilerSet errorformat=
  \%.%#lua%\\S%#:\ %f:%l:\ %m,
  \%-Gstack\ traceback:,
  \%-G%\\s%#[C]:%.%#,
  \%-G%\\s%#(...tail\ calls...),
  \%\\s%\\+%f:%l:\ in\ %m

let &cpo = s:save_cpo
unlet s:save_cpo
