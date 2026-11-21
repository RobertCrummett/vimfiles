" Layered on $VIMRUNTIME/ftplugin/lua.vim, which sets comments,
" commentstring, formatoptions, include, includeexpr and folding.

" :make runs the file with Lua. See compiler/lua.vim.
compiler lua

" makeprg and errorformat are what "compiler lua" set; the runtime file's
" undo command does not know about them.
let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal makeprg< errorformat< | unlet! b:current_compiler'
