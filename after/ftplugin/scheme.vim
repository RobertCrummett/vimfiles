" Layered on $VIMRUNTIME/ftplugin/scheme.vim, which sets comments,
" commentstring, define, iskeyword and a long list of scheme lispwords.

compiler racket

setlocal lisp
setlocal lispwords+=cond

" Read scheme with the racket syntax. synload.vim's "au FileType * set syntax="
" is registered before the ftplugin autocommand, because vimrc runs syntax on
" before filetype plugin indent on, so this setlocal lands after it and wins.
setlocal syntax=racket

augroup racket_syntax_for_scheme_files
  au!
  au Filetype scheme setlocal syntax=racket
augroup END

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal lisp< lispwords< syntax<'
