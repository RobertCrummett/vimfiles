" Layered on $VIMRUNTIME/ftplugin/racket.vim, which sets iskeyword, comments,
" commentstring, formatprg=raco fmt and K -> raco docs.

compiler racket

setlocal lisp
setlocal lispwords+=cond

" makeprg and errorformat are what "compiler racket" set; the runtime file's
" undo command does not know about them.
let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal lisp< lispwords< makeprg< errorformat<'
