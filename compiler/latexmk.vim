" latexmk as :make for LaTeX. Set by after/ftplugin/tex.vim.
"
" A folder with a latexmkrc has already said what to build, so latexmk gets no
" file name there; in a paper that can be the revision and its marked-up diff.
" Any other folder gets this file and -pdf: with no name latexmk builds every
" .tex file in the folder, and without -pdf it writes a .dvi. latexmk reads
" latexmkrc from where it runs, which is Vim's current directory. The vimrc
" has that follow the buffer, but only once the buffer is entered: when this
" is read, as the file opens, it is still the directory of the last buffer.
" So this looks in the folder of the file itself.
"
" -interaction=nonstopmode so that an error ends the run instead of waiting at
" TeX's prompt, and -file-line-error so that TeX reports file:line: message.
" The runtime compiler/tex.vim follows TeX's nesting of open files through the
" log instead, which is for TeX without -file-line-error.
"
" 'errorformat' keeps what latexmk really prints for a failure. Not all of it
" has a location: a missing package is "! LaTeX Error: ...", a brace left open
" is "! File ended while scanning ...", a file with no \end{document} is only
" "! Emergency stop.", and biber says "ERROR - ...". "==> Fatal error" follows
" every fatal error and says nothing about it, so it is left out. A second
" :make with nothing changed runs no TeX at all and says only that a rule
" "gave an error in previous invocation of latexmk". See |bgmake-errors|.
if exists("current_compiler")
  finish
endif
let current_compiler = "latexmk"

let s:save_cpo = &cpo
set cpo&vim

" Quoted by hand with forward slashes, not through %:S: see compiler/matlab.vim.
let s:makeprg = 'latexmk -interaction=nonstopmode -file-line-error'
if !filereadable(expand('%:p:h') . '/latexmkrc') && !filereadable(expand('%:p:h') . '/.latexmkrc')
  let s:makeprg .= ' -pdf "%:gs?\\?/?"'
endif
execute 'CompilerSet makeprg=' . escape(s:makeprg, ' \|"')
CompilerSet errorformat=%-G%.%#==>\ Fatal%.%#,%f:%l:\ %m,!\ %m,ERROR\ -\ %m,
  \%+G%.%#previous\ invocation\ of\ latexmk.,%-G%.%#

unlet s:makeprg
let &cpo = s:save_cpo
unlet s:save_cpo
