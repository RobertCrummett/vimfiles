" Layered on $VIMRUNTIME/ftplugin/c.vim instead of replacing it, so its
" commentstring, comments, define, include, omnifunc and matchit b:match_words
" survive. No b:did_ftplugin guard here: setting that is what suppressed them
" while this lived in ftplugin/c.vim.
"
" This also covers C++. The runtime ftplugin/cpp.vim does
"     runtime! ftplugin/c.vim ftplugin/c_*.vim ftplugin/c/*.vim
" and runtime! searches after/ too, so a cpp buffer picks this file up without
" a separate after/ftplugin/cpp.vim.

setlocal cindent
setlocal cinoptions+=:0,b1,l1

setlocal shiftwidth=4
setlocal softtabstop=-1

" The runtime file does fo+=croql, putting back the c that vimrc's fo-=tc
" removed. The flags come off one at a time: fo-=tc only matches a
" contiguous "tc", which croql does not contain.
setlocal formatoptions-=t formatoptions-=c

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal cindent< cinoptions< shiftwidth< softtabstop< formatoptions<'
