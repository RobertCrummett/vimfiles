" Layered on $VIMRUNTIME/ftplugin/scheme.vim, which sets comments,
" commentstring, define, iskeyword and a long list of scheme lispwords.

compiler racket

setlocal lisp
setlocal lispwords+=cond

" Read scheme with the racket syntax. synload.vim's "au FileType * set syntax="
" is registered before the ftplugin autocommand, because vimrc runs syntax on
" before filetype plugin indent on, so this setlocal lands after it and wins.
" That ordering holds on every FileType scheme, so no autocommand of our own
" is needed to repeat it.
setlocal syntax=racket

" makeprg and errorformat are what "compiler racket" set; the runtime file's
" undo command does not know about them.
let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal lisp< lispwords< syntax< makeprg< errorformat<'
