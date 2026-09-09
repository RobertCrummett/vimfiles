" The scratch buffers matlabdoc and matlabserver open: help text and command
" output. Not a real file type, the same way diredit and synexplore are not;
" the plugins set it with :setlocal filetype so this file can carry the
" window's behaviour instead of each of them repeating it.
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal nowrap nonumber norelativenumber nolist
setlocal textwidth=0 formatoptions-=t formatoptions-=c

" q closes the window; K looks up the name under the cursor, so a See also
" line in help, or a function named in Matlab's output, can be followed.
nnoremap <buffer> <silent> q <Cmd>close<CR>
setlocal keywordprg=:MatlabDoc

let b:undo_ftplugin = 'setlocal wrap< number< relativenumber< list< textwidth<'
  \ . ' formatoptions< keywordprg<'
  \ . ' | silent! nunmap <buffer> q'
