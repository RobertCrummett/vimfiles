if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal nowrap nonumber norelativenumber nolist
setlocal textwidth=0 formatoptions-=t formatoptions-=c

" q closes the help window; K on a name in a See also line looks that one up.
nnoremap <buffer> <silent> q <Cmd>close<CR>
setlocal keywordprg=:MatlabDoc

let b:undo_ftplugin = 'setlocal wrap< number< relativenumber< list< textwidth<'
  \ . ' formatoptions< keywordprg<'
  \ . ' | silent! nunmap <buffer> q'
