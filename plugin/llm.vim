" llm: completion from a local language model, in the i_CTRL-X style.
"
"   i_CTRL-X CTRL-A   suggest the next word, phrase or line (popup menu)
"   i_CTRL-X CTRL-B   suggest a block; streamed in as ghost text, CTRL-Y
"                     accepts what is shown, CTRL-E or typing dismisses
"
"   :LlmWarm          start the server and prime it with this buffer
"   :LlmStart :LlmStop :LlmStatus :LlmLog
"   :LlmModel [name]  :LlmModels  :LlmDownload {name}
"
" The server (llama-server) is started in the background on the first
" completion, never at startup, and stops when Vim exits or dies.
" See :help llm.
if exists('g:loaded_llm')
  finish
endif
let g:loaded_llm = 1

if !has('job') || !has('channel') || !has('textprop') || !exists('*json_decode')
  finish
endif

command! -bar                       LlmStart    call llm#start()
command! -bar                       LlmWarm     call llm#warm()
command! -bar                       LlmStop     call llm#stop()
command! -bar                       LlmStatus   call llm#status()
command! -bar                       LlmLog      call llm#log()
command! -bar -nargs=? -complete=customlist,llm#model_names LlmModel    call llm#set_model(<q-args>)
command! -bar                       LlmModels   call llm#models()
command! -bar -nargs=1 -complete=customlist,llm#model_names LlmDownload call llm#download(<q-args>)

inoremap <silent> <Plug>(llm_complete) <Cmd>call llm#complete_menu()<CR>
inoremap <silent> <Plug>(llm_block)    <Cmd>call llm#complete_block()<CR>

if !get(g:, 'llm_no_mappings', 0)
  imap <C-X><C-A> <Plug>(llm_complete)
  imap <C-X><C-B> <Plug>(llm_block)
endif

augroup llm_plugin
  autocmd!
  autocmd VimLeavePre * call llm#stop(1)
augroup END
