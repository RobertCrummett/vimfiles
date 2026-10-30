" Layered on $VIMRUNTIME/ftplugin/tex.vim.

" :make runs latexmk. See compiler/latexmk.vim.
compiler latexmk

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal makeprg< errorformat< | unlet! b:current_compiler'
