" Layered on $VIMRUNTIME/ftplugin/vim.vim, which sets commentstring and
" comments (per legacy/Vim9 script), include, define, omnifunc, path,
" matchit b:match_words and the [[ ]] [] ][ motions.

setlocal shiftwidth=2
setlocal softtabstop=2

setlocal comments+=:\"

" The runtime file does fo+=croql, putting back the c that vimrc's fo-=tc
" removed. The flags come off one at a time: fo-=tc only matches a
" contiguous "tc", which croql does not contain.
setlocal formatoptions-=t formatoptions-=c

setlocal keywordprg=:help

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal shiftwidth< softtabstop< comments< formatoptions< keywordprg<'
