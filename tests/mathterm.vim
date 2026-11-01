" The llm plugin beside mathterm. Stand-in servers, a stand-in of the file a
" window writes, and the plugin as it is. Run with
"   vim -u NONE -N -es -S tests/mathterm.vim
" from the root of this repository, and read tests/mathterm.out, which ends in
" `passed N` or lists what failed. No real server, and nothing on a card.

set nocompatible
let s:here = expand('<sfile>:p:h')
let s:root = fnamemodify(s:here, ':h')
execute 'set runtimepath^=' . fnameescape(s:root)
runtime plugin/llm.vim
let $MATHTERM_DATA = tempname()
call mkdir($MATHTERM_DATA, 'p')
let s:file = $MATHTERM_DATA . '/model.txt'
let s:log = tempname()
" A path that is not there: reaching it says the plugin went on to start its own.
let g:llm_server = $MATHTERM_DATA . '/no-llama-server.exe'
let g:llm_model = 'qwen2.5-coder-3b'
let g:llm_model_dirs = [$MATHTERM_DATA]
call writefile([], $MATHTERM_DATA . '/qwen2.5-coder-3b-q8_0.gguf')
let s:main_port = 18931
let s:helper_port = 18932
let s:jobs = []
let s:failed = []
let s:passed = 0

function! s:stand_in(port, model, ...) abort
  let l:args = ['python', s:here . '/stand_in.py', string(a:port), s:log, a:model] + a:000
  let l:job = job_start(l:args, {'in_io': 'null', 'out_io': 'null', 'err_io': 'null'})
  call add(s:jobs, l:job)
  let l:start = reltime()
  while reltimefloat(reltime(l:start)) < 10
    let l:ch = ch_open('127.0.0.1:' . a:port, {'mode': 'raw', 'waittime': 100})
    if ch_status(l:ch) ==# 'open'
      call ch_close(l:ch)
      return l:job
    endif
    sleep 50m
  endwhile
  throw 'no stand-in on ' . a:port
endfunction

function! s:stop(job) abort
  call job_stop(a:job, 'kill')
  sleep 300m
endfunction

function! s:window(main, helper) abort
  call writefile(['window = 1', 'process = 1', 'main = ' . a:main,
    \ 'main_address = 127.0.0.1:' . s:main_port, 'helper = ' . a:helper,
    \ 'helper_address = 127.0.0.1:' . s:helper_port], s:file)
endfunction

function! s:requests() abort
  return filereadable(s:log) ? map(readfile(s:log), 'json_decode(v:val)') : []
endfunction

function! s:paths() abort
  return map(s:requests(), 'v:val.path')
endfunction

function! s:fresh() abort
  call llm#stop(1)
  call llm#reset_last()
  call delete(s:log)
endfunction

" Ask, and let the callbacks run.
function! s:warm() abort
  LlmWarm
  let l:start = reltime()
  while reltimefloat(reltime(l:start)) < 3
    sleep 50m
    if !empty(llm#last())
      break
    endif
  endwhile
  sleep 100m
endfunction

function! s:is(what, got, wanted) abort
  if a:got ==# a:wanted
    let s:passed += 1
  else
    call add(s:failed, a:what . ': got ' . string(a:got) . ', wanted ' . string(a:wanted))
  endif
endfunction

function! s:said(what, pattern) abort
  if execute('messages') =~# a:pattern
    let s:passed += 1
  else
    call add(s:failed, a:what . ': no message like ' . a:pattern)
  endif
  messages clear
endfunction

function! s:run() abort
  call setline(1, ['let x = 1', 'let y = 2'])
  normal! G$

  " The helper before the model, asked for what goes on from the cursor.
  let l:helper = s:stand_in(s:helper_port, 'C:\models\Qwen3.5-4B-Q4_K_M.gguf')
  let l:main = s:stand_in(s:main_port, '..\..\models\Ternary-Bonsai-2-27B-PQ2_0.gguf')
  call s:window('on', 'on')
  call s:warm()
  call s:is('helper first', s:paths(), ['/props', '/slots', '/completion'])
  call s:said('names what it uses', 'using the helper in mathterm: Qwen3.5-4B-Q4_K_M.gguf')
  call s:is('a text sent', s:requests()[-1].body.prompt =~# 'let x = 1', 1)

  " The second request does not ask what is loaded again.
  call llm#reset_last()
  call delete(s:log)
  call s:warm()
  call s:is('second request', s:paths(), ['/slots', '/completion'])

  " The helper goes: the model is next, seen on the next request.
  call s:window('on', 'off: stopped when asked')
  call llm#reset_last()
  call delete(s:log)
  call s:warm()
  call s:is('the model next', s:paths(), ['/props', '/slots', '/completion'])
  call s:said('names the model', 'using the model in mathterm: Ternary-Bonsai')
  call s:stop(l:helper)

  " A model the registry knows for fill-in-the-middle is asked that way.
  call s:fresh()
  call s:stop(l:main)
  let l:main = s:stand_in(s:main_port, 'C:\models\Qwen2.5-Coder-7B.Q4_K_M.gguf')
  call s:window('on', 'off')
  call s:warm()
  call s:is('fill-in-the-middle', s:paths(), ['/props', '/slots', '/infill'])
  call s:stop(l:main)

  " A context too small for what the plugin would send: the end of it goes.
  call s:fresh()
  let l:main = s:stand_in(s:main_port, 'bonsai.gguf')
  let l:long = map(range(1, 180), '"line " . v:val . " " . repeat("x", 60)')
  call setline(1, l:long)
  normal! G$
  call s:warm()
  let l:sent = s:requests()[-1].body.prompt
  call s:is('fits the context', len(l:sent) <= (2000 - 1) * 2, 1)
  call s:is('and keeps the end', l:sent =~# 'line 180', 1)
  call setline(1, ['let x = 1', 'let y = 2'])
  silent 3,$delete _
  call s:stop(l:main)

  " Busy: nothing is sent, and it says so. A long answer is not waited behind.
  call s:fresh()
  let l:main = s:stand_in(s:main_port, 'bonsai.gguf', 'busy')
  call s:warm()
  call s:is('busy', s:paths(), ['/props', '/slots'])
  call s:is('busy, said', llm#last(), {'outcome': 'busy'})
  call s:stop(l:main)

  " Still loading: nothing else is started beside it.
  call s:fresh()
  let l:main = s:stand_in(s:main_port, 'bonsai.gguf', 'loading')
  messages clear
  call s:warm()
  call s:is('loading', s:paths(), ['/props'])
  call s:said('loading, said', 'still loading')
  call s:stop(l:main)

  " On its way up or down: not even a look, and nothing started.
  call s:fresh()
  for l:state in ['starting', 'stopping']
    call s:window(l:state, 'off')
    messages clear
    call s:warm()
    call s:said(l:state, 'the model in mathterm is ' . l:state)
  endfor

  " A file a dead window left, and no window at all: the plugin's own way.
  call s:fresh()
  call s:window('on', 'off')
  messages clear
  call s:warm()
  call s:said('dead window', 'no-llama-server.exe does not exist')
  call s:fresh()
  call delete(s:file)
  messages clear
  call s:warm()
  call s:said('no window', 'no-llama-server.exe does not exist')

  " Told not to look.
  call s:fresh()
  let l:main = s:stand_in(s:main_port, 'bonsai.gguf')
  call s:window('on', 'off')
  let g:llm_mathterm = 0
  messages clear
  call s:warm()
  call s:is('told not to', s:paths(), [])
  call s:said('told not to, said', 'no-llama-server.exe does not exist')
  unlet g:llm_mathterm

  " It is left running when Vim goes.
  call s:fresh()
  call s:warm()
  call llm#stop(1)
  call s:is('left alone', job_status(l:main), 'run')
  call s:stop(l:main)
endfunction

try
  call s:run()
catch
  call add(s:failed, 'threw ' . v:exception . ' at ' . v:throwpoint)
endtry
for s:job in s:jobs
  silent! call job_stop(s:job, 'kill')
endfor
call writefile(s:failed + ['passed ' . s:passed], s:here . '/mathterm.out')
qall!
