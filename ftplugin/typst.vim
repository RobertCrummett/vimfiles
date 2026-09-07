if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

compiler typst

setlocal nojoinspaces

" Typst identifiers may contain dashes (row-gutter, my-func); the bundled
" syntax matches identifiers with \k, so make - a keyword character.
setlocal iskeyword+=-
