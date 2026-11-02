" Layered on $VIMRUNTIME/ftplugin/typst.vim, which sets commentstring,
" comments, formatoptions, formatlistpat and suffixesadd=.typ.

compiler typst

setlocal nojoinspaces

" The runtime file does fo+=croqn, putting back the c that vimrc's fo-=tc
" removed. The flags come off one at a time: fo-=tc only matches a
" contiguous "tc", which croqn does not contain.
setlocal formatoptions-=t formatoptions-=c

" The n in croqn stays, for the - + / lists. A number starts a list item only
" as Typst reads one, "1. ": the runtime's pattern also takes 0.9 and 10 km,
" which often start a line of prose, and gq then stops joining there.
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*[-+/]\\s\\+

" Typst identifiers may contain dashes (row-gutter, my-func); the bundled
" syntax matches identifiers with \k, so make - a keyword character.
setlocal iskeyword+=-

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal joinspaces< iskeyword< formatoptions< formatlistpat<'
