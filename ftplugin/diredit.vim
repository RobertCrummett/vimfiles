if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Hide the entry ids; keep them hidden while editing so the line reads as
" just the name.
setlocal conceallevel=2 concealcursor=nvic
setlocal nowrap nonumber norelativenumber cursorline
setlocal textwidth=0 formatoptions-=t formatoptions-=c
setlocal noexpandtab

nnoremap <buffer> <silent> <CR> <Cmd>call diredit#select()<CR>
nnoremap <buffer> <silent> -    <Cmd>call diredit#open_parent()<CR>
nnoremap <buffer> <silent> R    <Cmd>edit!<CR>
nnoremap <buffer> <silent> g.   <Cmd>call diredit#toggle_hidden()<CR>
nnoremap <buffer> <silent> gl   <Cmd>call diredit#toggle_details()<CR>
nnoremap <buffer> <silent> g?   <Cmd>call diredit#help()<CR>

let b:undo_ftplugin = 'setlocal conceallevel< concealcursor< wrap< number< relativenumber<'
  \ . ' cursorline< textwidth< formatoptions< expandtab<'
  \ . ' | silent! nunmap <buffer> <CR> | silent! nunmap <buffer> - | silent! nunmap <buffer> R'
  \ . ' | silent! nunmap <buffer> g. | silent! nunmap <buffer> gl | silent! nunmap <buffer> g?'
