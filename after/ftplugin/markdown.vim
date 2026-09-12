" Layered on $VIMRUNTIME/ftplugin/markdown.vim, which sets comments,
" commentstring, formatoptions, formatlistpat and the [[ ]] motions.

" gq on a table lines its columns up; see autoload/markdown.vim. Anything
" that is not a table is formatted by Vim as before.
setlocal formatexpr=markdown#format()

" The runtime file does fo+=tcqln, putting back the t and c that vimrc's
" fo-=tc removed. The flags come off one at a time: fo-=tc only matches a
" contiguous "tc", which tcqln does contain, but the runtime's order is
" not to be relied on.
setlocal formatoptions-=t formatoptions-=c

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal formatexpr< formatoptions<'
