if exists('b:current_syntax')
  finish
endif

" Lines are "id<Tab>details<Tab>name". The id and both tabs are hidden;
" the details column is dimmed; the name is what you edit.
syntax match direditId      /^\d\+\t/ conceal
syntax match direditSep     /\t/ conceal contained
syntax match direditDetails /^\d\+\t\zs[^\t]*\t/ contains=direditSep
syntax match direditDir     /\%(^\|\t\)\zs[^\t]*\/$/
" A line without an id is a new entry that :w will create.
syntax match direditNew     /^[^\t]*$/

highlight default link direditDetails Comment
highlight default link direditDir     Directory
highlight default link direditNew     Added

let b:current_syntax = 'diredit'
