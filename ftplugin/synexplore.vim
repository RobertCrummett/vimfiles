if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal nowrap nonumber norelativenumber nolist
setlocal textwidth=0 formatoptions-=t formatoptions-=c

" q closes the report (it is wiped); :w {name} keeps it as a real file.
nnoremap <buffer> <silent> q <Cmd>close<CR>

augroup synexplore_write
  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call synexplore#write()
augroup END

let b:undo_ftplugin = 'setlocal wrap< number< relativenumber< list< textwidth< formatoptions<'
  \ . ' | silent! nunmap <buffer> q | autocmd! synexplore_write * <buffer>'
