" llm: local language-model completion through llama-server. See :help llm.

let s:root = expand('<sfile>:p:h:h')
let s:state = 'stopped'        " stopped | starting | ready | external
let s:job = v:null             " the server job (only when we started it)
let s:req = v:null             " the in-flight request (see s:http)
let s:pending = []             " closures waiting for the server
let s:log = []
let s:ghost = {}
let s:last = {}                " timings of the last completion
let s:poll_started = 0
let s:req_started = 0          " reltime() of the in-flight request
let s:req_what = ''            " what it is for, for progress messages

" ------------------------------------------------------------ messages

" Milestones go through :echomsg, so :messages keeps them in full; from a
" callback that never stops for a hit-enter prompt (measured up to 200
" characters). Progress lines use :echo so they replace each other and
" stay out of :messages, but an :echo from a callback does stop for a
" hit-enter prompt as soon as it reaches the 'showcmd' and 'ruler' area,
" so they are cut to fit.
function! s:say(msg) abort
  call add(s:log, a:msg)
  redraw
  echomsg a:msg
endfunction

function! s:progress(msg) abort
  redraw
  echo strpart(a:msg, 0, s:room())
endfunction

" How much of the command line an :echo may use.
function! s:room() abort
  let l:room = &columns - 1
  if &showcmd
    let l:room -= 11
  endif
  if &ruler && (&laststatus == 0 || (&laststatus == 1 && winnr('$') == 1))
    let l:room -= 18
  endif
  return l:room
endfunction

" The server's most recent log line, cut to fit after a prefix.
function! s:last_log_line(room) abort
  for l:i in range(len(s:log) - 1, 0, -1)
    let l:l = trim(s:log[l:i])
    if !empty(l:l) && l:l !~# '^llm:'
      return strpart(l:l, 0, max([a:room, 20]))
    endif
  endfor
  return ''
endfunction

" ------------------------------------------------------------- options

function! s:opt(name, default) abort
  return get(g:, 'llm_' . a:name, a:default)
endfunction

function! s:port() abort
  return s:opt('port', 8797)
endfunction

function! s:url(path) abort
  return 'http://127.0.0.1:' . s:port() . a:path
endfunction

" ------------------------------------------------------------- registry

" Entries of models/registry.txt: {name, repo, file, fim, notes}.
function! llm#registry() abort
  let l:out = []
  let l:file = s:root . '/models/registry.txt'
  if !filereadable(l:file)
    return l:out
  endif
  for l:line in readfile(l:file)
    if l:line =~# '^\s*#' || l:line =~# '^\s*$'
      continue
    endif
    let l:f = split(l:line)
    if len(l:f) < 4
      continue
    endif
    call add(l:out, {'name': l:f[0], 'repo': l:f[1], 'file': l:f[2],
      \ 'fim': l:f[3] ==? 'yes', 'notes': join(l:f[4:], ' ')})
  endfor
  return l:out
endfunction

function! llm#model_names(lead, ...) abort
  return filter(map(llm#registry(), 'v:val.name'), 'v:val =~# "^" . a:lead')
endfunction

function! s:entry(name) abort
  for l:e in llm#registry()
    if l:e.name ==# a:name
      return l:e
    endif
  endfor
  return {}
endfunction

" Directories searched for weights: our models/ dir, then llama.cpp's own
" download cache (files there carry the repo as a prefix).
function! s:model_dirs() abort
  let l:dirs = [s:root . '/models']
  if has('win32')
    call add(l:dirs, expand('$LOCALAPPDATA') . '/llama.cpp')
  else
    call add(l:dirs, expand('~/.cache/llama.cpp'))
  endif
  return l:dirs + s:opt('model_dirs', [])
endfunction

" Path of the weights for a registry name (or a path given directly).
function! llm#model_path(name) abort
  if filereadable(a:name)
    return a:name
  endif
  let l:e = s:entry(a:name)
  if empty(l:e)
    return ''
  endif
  for l:dir in s:model_dirs()
    let l:hits = glob(l:dir . '/' . l:e.file, 1, 1) + glob(l:dir . '/*_' . l:e.file, 1, 1)
    if !empty(l:hits)
      return l:hits[0]
    endif
  endfor
  return ''
endfunction

function! s:model_name() abort
  return s:opt('model', 'qwen2.5-coder-3b')
endfunction

function! s:model_is_fim() abort
  let l:e = s:entry(s:model_name())
  return empty(l:e) ? 1 : l:e.fim
endfunction

function! llm#models() abort
  echo printf('%-20s %-6s %-10s %s', 'name', 'fim', 'weights', 'notes')
  for l:e in llm#registry()
    let l:p = llm#model_path(l:e.name)
    echo printf('%-20s %-6s %-10s %s%s', l:e.name, l:e.fim ? 'yes' : 'no',
      \ empty(l:p) ? 'missing' : 'present', l:e.notes,
      \ l:e.name ==# s:model_name() ? '  <- current' : '')
  endfor
endfunction

function! llm#set_model(name) abort
  if empty(a:name)
    echo 'llm: model is ' . s:model_name() . ' (' . (empty(llm#model_path(s:model_name())) ? 'weights missing' : llm#model_path(s:model_name())) . ')'
    return
  endif
  if empty(s:entry(a:name)) && !filereadable(a:name)
    echohl ErrorMsg | echomsg 'llm: unknown model ' . a:name . ' (see :LlmModels)' | echohl None
    return
  endif
  let g:llm_model = a:name
  if s:state ==# 'ready' || s:state ==# 'starting'
    call llm#stop()
    echo 'llm: model set to ' . a:name . '; the server restarts on the next completion'
  else
    echo 'llm: model set to ' . a:name
  endif
endfunction

" Fetch weights from Hugging Face into models/.
function! llm#download(name) abort
  let l:e = s:entry(a:name)
  if empty(l:e)
    echohl ErrorMsg | echomsg 'llm: unknown model ' . a:name . ' (see :LlmModels)' | echohl None
    return
  endif
  if !empty(llm#model_path(a:name))
    echo 'llm: ' . a:name . ' is already at ' . llm#model_path(a:name)
    return
  endif
  let l:dir = s:root . '/models'
  let l:dest = l:dir . '/' . l:e.file
  let l:url = 'https://huggingface.co/' . l:e.repo . '/resolve/main/' . l:e.file
  let l:cmd = ['curl', '-L', '-sS', '--fail', '-o', l:dest . '.part', l:url]
  echo 'llm: downloading ' . l:e.file . ' (' . l:e.notes . ') ...'
  call job_start(l:cmd, {'in_io': 'null',
    \ 'exit_cb': {j, status -> s:download_done(l:e, l:dest, status)}})
endfunction

function! s:download_done(entry, dest, status) abort
  if a:status == 0 && rename(a:dest . '.part', a:dest) == 0
    echomsg 'llm: downloaded ' . a:entry.name . ' -> ' . a:dest
  else
    call delete(a:dest . '.part')
    echohl ErrorMsg | echomsg 'llm: download of ' . a:entry.name . ' failed (curl exit ' . a:status . ')' | echohl None
  endif
endfunction

" ------------------------------------------------------------ the server

function! s:server_exe() abort
  let l:exe = s:opt('server', '')
  if !empty(l:exe)
    return l:exe
  endif
  let l:exe = exepath('llama-server')
  if !empty(l:exe)
    return l:exe
  endif
  if has('win32')
    let l:hits = glob(expand('$LOCALAPPDATA') . '/Microsoft/WinGet/Packages/ggml.llamacpp*/llama-server.exe', 1, 1)
    if !empty(l:hits)
      return l:hits[0]
    endif
  endif
  return ''
endfunction

" Wrap the server command so that it dies with Vim even if Vim crashes:
" a small watchdog that waits for either process to end and then kills the
" other. On a clean exit Vim kills the whole job tree itself.
" PowerShell single-quoted literal.
function! s:psq(s) abort
  return "'" . substitute(a:s, "'", "''", 'g') . "'"
endfunction

function! s:watchdog(cmd) abort
  let l:pid = getpid()
  if has('win32')
    let l:script = '$p = Start-Process -PassThru -NoNewWindow -FilePath ' . s:psq(a:cmd[0])
      \ . ' -ArgumentList @(' . join(map(a:cmd[1:], 's:psq(v:val)'), ',') . ');'
      \ . ' while (-not $p.HasExited -and (Get-Process -Id ' . l:pid . ' -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 500 };'
      \ . ' if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }'
    return ['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', l:script]
  endif
  let l:script = '"$0" "$@" & c=$!; trap "kill $c 2>/dev/null" EXIT TERM INT;'
    \ . ' while kill -0 ' . l:pid . ' 2>/dev/null && kill -0 $c 2>/dev/null; do sleep 1; done'
  return ['sh', '-c', l:script] + a:cmd
endfunction

" The full command the server is (or would be) started with; shown by
" :LlmStatus and handy when a start fails.
function! llm#command() abort
  let l:exe = s:server_exe()
  let l:model = llm#model_path(s:model_name())
  if empty(l:exe) || empty(l:model)
    return []
  endif
  return s:watchdog(s:server_cmd(l:exe, l:model))
endfunction

" g:llm_slots prompt caches of g:llm_ctx tokens each; the server's total
" context is the product. One is the default: with two, requests from a
" single Vim sometimes stalled for seconds when the server ran two
" sequences in one batch, and re-warming after switching Vims costs about
" a second.
function! s:server_cmd(exe, model) abort
  let l:slots = max([1, s:opt('slots', 1)])
  return [a:exe, '-m', a:model, '--host', '127.0.0.1', '--port', string(s:port()),
    \ '-ngl', string(s:opt('gpu_layers', 99)),
    \ '-c', string(s:opt('ctx', 8192) * l:slots), '-np', string(l:slots),
    \ '-fa', 'on', '--cache-reuse', '256', '--no-webui'] + s:opt('server_args', [])
endfunction

" ---------------------------------------------------------- http client

" The server is spoken to over a raw channel: no process per request (a
" curl spawn alone cost about 100 ms on Windows), no temp file, and a
" cancel is just closing the socket. Just enough HTTP/1.1 for a local
" llama-server: one request per connection, Content-Length or chunked
" replies.
"
" s:http() returns a request record; Cb gets {'status', 'body'} or
" {'error': 'connect' | 'timeout' | 'closed'}. With a Stream function,
" Stream(body so far) is also called as the body arrives, which is how a
" block shows up word by word.
function! s:http(method, path, body, Cb, timeout_ms, ...) abort
  let l:r = {'buf': '', 'pos': 0, 'body': '', 'hdr': 0, 'chunked': 0, 'clen': -1, 'complete': 0,
    \ 'done': 0, 'status': 0, 'Cb': a:Cb, 'Stream': a:0 ? a:1 : v:null, 'start': reltime(), 'timer': -1}
  let l:ch = ch_open('127.0.0.1:' . s:port(), {'mode': 'raw', 'waittime': 300, 'drop': 'never',
    \ 'callback': function('s:http_data', [l:r]), 'close_cb': function('s:http_closed', [l:r])})
  let l:r.ch = l:ch
  if ch_status(l:ch) !=# 'open'
    let l:r.done = 1
    call a:Cb({'error': 'connect'})
    return l:r
  endif
  let l:req = a:method . ' ' . a:path . " HTTP/1.1\r\nHost: 127.0.0.1:" . s:port()
    \ . "\r\nConnection: close\r\nAccept: application/json\r\n"
  if !empty(a:body)
    let l:req .= "Content-Type: application/json\r\nContent-Length: " . len(a:body) . "\r\n"
  endif
  call ch_sendraw(l:ch, l:req . "\r\n" . a:body)
  let l:r.timer = timer_start(a:timeout_ms, function('s:http_timeout', [l:r]))
  return l:r
endfunction

function! s:http_data(r, ch, msg) abort
  if a:r.done
    return
  endif
  let a:r.buf .= a:msg
  let l:grew = s:http_drain(a:r)
  if a:r.complete
    call s:http_finish(a:r, {'status': a:r.status, 'body': a:r.body})
  elseif l:grew && a:r.Stream isnot v:null
    call a:r.Stream(a:r.body)
  endif
endfunction

" Move what has arrived in r.buf into r.body: parse the headers once, then
" de-chunk or count against Content-Length. Sets r.complete when the whole
" body is in; returns 1 when the body grew.
function! s:http_drain(r) abort
  if !a:r.hdr
    let l:hdr_end = stridx(a:r.buf, "\r\n\r\n")
    if l:hdr_end < 0
      return 0
    endif
    let l:headers = strpart(a:r.buf, 0, l:hdr_end)
    let a:r.status = str2nr(matchstr(l:headers, '^HTTP/\S\+\s\+\zs\d\+'))
    let a:r.chunked = l:headers =~? '\nTransfer-Encoding:\s*chunked'
    let l:len = matchstr(l:headers, '\c\nContent-Length:\s*\zs\d\+')
    let a:r.clen = empty(l:len) ? -1 : str2nr(l:len)
    let a:r.pos = l:hdr_end + 4
    let a:r.hdr = 1
  endif
  let l:before = len(a:r.body)
  if a:r.chunked
    while 1
      let l:nl = stridx(a:r.buf, "\r\n", a:r.pos)
      if l:nl < 0
        break
      endif
      let l:size = str2nr(matchstr(strpart(a:r.buf, a:r.pos, l:nl - a:r.pos), '^\x\+'), 16)
      if l:size == 0
        let a:r.complete = 1
        break
      endif
      if len(a:r.buf) < l:nl + 2 + l:size + 2
        break
      endif
      let a:r.body .= strpart(a:r.buf, l:nl + 2, l:size)
      let a:r.pos = l:nl + 2 + l:size + 2
    endwhile
  else
    let a:r.body .= strpart(a:r.buf, a:r.pos)
    let a:r.pos = len(a:r.buf)
    if a:r.clen >= 0 && len(a:r.body) >= a:r.clen
      let a:r.body = strpart(a:r.body, 0, a:r.clen)
      let a:r.complete = 1
    endif
  endif
  return len(a:r.body) > l:before
endfunction

" The server closed the connection: whatever arrived is the whole reply.
function! s:http_closed(r, ch) abort
  if a:r.done
    return
  endif
  call s:http_drain(a:r)
  call s:http_finish(a:r, a:r.hdr ? {'status': a:r.status, 'body': a:r.body} : {'error': 'closed'})
endfunction

function! s:http_timeout(r, timer) abort
  call s:http_finish(a:r, {'error': 'timeout'})
endfunction

function! s:http_cancel(r) abort
  if !a:r.done
    let a:r.done = 1
    call timer_stop(a:r.timer)
    silent! call ch_close(a:r.ch)
  endif
endfunction

function! s:http_finish(r, result) abort
  if a:r.done
    return
  endif
  call s:http_cancel(a:r)
  call a:r.Cb(a:result)
endfunction

" Ask the server's /health endpoint; Cb(1) if it says ok, Cb(0) otherwise
" (including when nothing is listening).
" Cb('ok') when a server answers and is ready, Cb('loading') when one
" answers but is not (llama-server listens while the weights load),
" Cb('down') when nothing answers.
function! s:health(Cb) abort
  call s:http('GET', '/health', '', {r -> a:Cb(has_key(r, 'error') ? 'down'
    \ : get(r, 'status', 0) == 200 && get(r, 'body', '') =~# '"ok"' ? 'ok' : 'loading')}, 2000)
endfunction

" Start the server unless one is already answering on the port. Returns 1
" when a server is ready or on its way, 0 when it cannot be started.
function! llm#start() abort
  if s:state ==# 'ready' || s:state ==# 'starting' || s:state ==# 'external'
    return 1
  endif
  if empty(s:server_exe())
    echohl ErrorMsg
    echomsg 'llm: llama-server not found; install llama.cpp (winget install ggml.llamacpp) or set g:llm_server'
    echohl None
    return 0
  endif
  if empty(llm#model_path(s:model_name()))
    echohl ErrorMsg
    echomsg 'llm: no weights for ' . s:model_name() . '; run :LlmDownload ' . s:model_name() . ' or :LlmModels'
    echohl None
    return 0
  endif
  let s:state = 'starting'
  call s:progress('llm: looking for a llama-server on port ' . s:port() . ' ...')
  call s:health(function('s:start_after_probe'))
  return 1
endfunction

" First probe result: reuse a running server, or launch our own.
function! s:start_after_probe(health) abort
  if s:state !=# 'starting'
    return
  endif
  if a:health ==# 'ok'
    let s:state = 'external'
    call s:say('llm: using the llama-server already running on port ' . s:port())
    call s:flush_pending()
    return
  endif
  if a:health ==# 'loading'
    " Another Vim's server is coming up; wait for it rather than fight it
    " for the port.
    let s:poll_started = localtime()
    call s:say('llm: a llama-server on port ' . s:port() . ' is still loading; waiting for it')
    call timer_start(700, function('s:poll'))
    return
  endif
  let l:exe = s:server_exe()
  if empty(l:exe)
    echohl ErrorMsg
    echomsg 'llm: llama-server not found; install llama.cpp (winget install ggml.llamacpp) or set g:llm_server'
    echohl None
    return 0
  endif
  let l:model = llm#model_path(s:model_name())
  let l:cmd = s:server_cmd(l:exe, l:model)
  let s:log = ['llm: ' . join(l:cmd, ' ')]
  let s:job = job_start(s:watchdog(l:cmd), {
    \ 'in_io': 'null',
    \ 'out_cb': function('s:log_cb'), 'err_cb': function('s:log_cb'),
    \ 'exit_cb': function('s:exit_cb'),
    \ 'stoponexit': 'kill',
    \ })
  if job_status(s:job) !=# 'run'
    let s:state = 'stopped'
    let s:pending = []
    echohl ErrorMsg | echomsg 'llm: could not start ' . l:exe | echohl None
    return
  endif
  let s:poll_started = localtime()
  call s:say(printf('llm: started llama-server: %s, %.1f GB of weights, loading onto the GPU ...',
    \ s:model_name(), getfsize(l:model) / 1073741824.0))
  if !empty(s:pending)
    call s:say('llm: what you asked for runs as soon as it is ready')
  endif
  call timer_start(700, function('s:poll'))
endfunction

" Probe until the server answers, then run what was waiting.
function! s:poll(timer) abort
  if s:state !=# 'starting'
    return
  endif
  call s:health(function('s:poll_result'))
endfunction

function! s:poll_result(health) abort
  if s:state !=# 'starting'
    return
  endif
  let l:elapsed = localtime() - s:poll_started
  let l:ours = s:job isnot v:null
  if a:health ==# 'ok'
    let s:state = l:ours ? 'ready' : 'external'
    call s:say(printf('llm: server ready after %d s (%s)', l:elapsed, s:model_name()))
    call s:flush_pending()
  elseif !l:ours && a:health ==# 'down'
    " The server we were waiting for went away; start our own.
    call s:say('llm: the server we were waiting for is gone; starting one')
    call s:start_after_probe('down')
  elseif l:elapsed > s:opt('start_timeout', 180)
    echohl ErrorMsg | echomsg 'llm: server did not become ready; see :LlmLog' | echohl None
    call llm#stop()
  else
    let l:head = printf('llm: loading %s, %d s: ', s:model_name(), l:elapsed)
    call s:progress(l:head . s:last_log_line(&columns - len(l:head) - 2))
    call timer_start(700, function('s:poll'))
  endif
endfunction

" Run what waited for the server. An error inside a callback would
" otherwise flash by and look like nothing happened, so report it.
function! s:flush_pending() abort
  let l:queue = s:pending
  let s:pending = []
  for l:Fn in l:queue
    call s:guarded(l:Fn, [])
  endfor
endfunction

function! s:guarded(Fn, args) abort
  try
    call call(a:Fn, a:args)
  catch
    call add(s:log, 'llm: error: ' . v:exception . ' at ' . v:throwpoint)
    echohl ErrorMsg | echomsg 'llm: error: ' . v:exception . ' (see :LlmLog)' | echohl None
  endtry
endfunction

function! s:log_cb(channel, msg) abort
  call add(s:log, a:msg)
  if len(s:log) > 400
    call remove(s:log, 0, 99)
  endif
endfunction

function! s:exit_cb(job, status) abort
  if s:state !=# 'stopped'
    let s:state = 'stopped'
    let s:pending = []
    let s:job = v:null
    if a:status != 0
      echohl WarningMsg
      echomsg 'llm: server exited with status ' . a:status . ': ' . s:last_log_line(200) . ' (see :LlmLog)'
      echohl None
    endif
  endif
endfunction

" Stop the server if we started it. A server found already running is
" left alone unless "force" is given.
function! llm#stop(...) abort
  let l:quiet = a:0 && a:1
  call llm#dismiss()
  if s:req isnot v:null
    call s:http_cancel(s:req)
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job, 'kill')
  endif
  let s:job = v:null
  let s:pending = []
  let l:was = s:state
  let s:state = 'stopped'
  if !l:quiet
    echo l:was ==# 'external' ? 'llm: not stopping a server this Vim did not start' : 'llm: stopped'
  endif
endfunction

function! llm#status() abort
  let l:lines = ['llm: ' . s:state . ', model ' . s:model_name() . ', port ' . s:port()]
  let l:p = llm#model_path(s:model_name())
  call add(l:lines, '  weights: ' . (empty(l:p) ? 'missing (:LlmDownload ' . s:model_name() . ')' : l:p))
  call add(l:lines, '  server:  ' . (empty(s:server_exe()) ? 'llama-server not found' : s:server_exe()))
  if !empty(s:last)
    call add(l:lines, printf('  last request: %s; %d prompt tokens processed, %d reused from cache, %d predicted at %.0f tok/s, %.0f ms total',
      \ get(s:last, 'outcome', '?'), get(s:last, 'prompt_n', 0), get(s:last, 'cached', 0), get(s:last, 'predicted_n', 0),
      \ get(s:last, 'predicted_per_second', 0.0), get(s:last, 'total_ms', 0.0)))
  endif
  echo join(l:lines, "\n")
endfunction

" Timings and outcome of the last request (for scripts and tests).
function! llm#last() abort
  return copy(s:last)
endfunction

function! llm#reset_last() abort
  let s:last = {}
endfunction

function! llm#log() abort
  keepalt new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  call setline(1, empty(s:log) ? ['(no server output yet)'] : s:log)
  setlocal nomodified
  execute 'silent keepalt file' fnameescape('[LlmLog]')
endfunction

" ------------------------------------------------------------- requests

" POST a JSON body to the server and call Cb(response dict). A request
" still in flight is cancelled first, so a quick repeat never queues up.
" With a Progress function the request is streamed and Progress(text so
" far) is called as the model produces it.
function! s:post(path, body, Cb, what, ...) abort
  if s:req isnot v:null
    call s:http_cancel(s:req)
  endif
  let s:req_what = a:what
  let l:ctx = {'Cb': a:Cb, 'start': reltime(), 'Progress': a:0 ? a:1 : v:null}
  if l:ctx.Progress isnot v:null
    let a:body.stream = v:true
  endif
  let s:req = s:http('POST', a:path, json_encode(a:body), function('s:post_done', [l:ctx]),
    \ s:opt('timeout', 90) * 1000,
    \ l:ctx.Progress is v:null ? v:null : function('s:post_stream', [l:ctx]))
  let s:req_started = l:ctx.start
  call timer_start(1500, function('s:req_progress', [l:ctx.start]))
endfunction

" A streamed reply is server-sent events, one JSON object per "data:"
" line; the text is the concatenated "content" fields and the last event
" (stop: true) carries the timings.
function! s:sse_events(body) abort
  let l:events = []
  for l:line in split(a:body, "\n")
    if l:line =~# '^data: *{'
      try
        call add(l:events, json_decode(substitute(l:line, '^data: *', '', '')))
      catch
        " a partial last line; it comes again complete
      endtry
    endif
  endfor
  return l:events
endfunction

function! s:sse_merge(events) abort
  if empty(a:events)
    return {}
  endif
  let l:resp = copy(a:events[-1])
  let l:resp.content = join(map(copy(a:events), 'get(v:val, "content", "")'), '')
  return l:resp
endfunction

function! s:post_stream(ctx, body) abort
  call a:ctx.Progress(s:sse_merge(s:sse_events(a:body)))
endfunction

" While a request runs longer than a moment, say so once a second: the
" first request in a file is processing the whole context, later ones
" only what changed.
function! s:req_progress(start, timer) abort
  " Only for the request that started this timer, and only while it runs.
  if a:start isnot s:req_started || s:req is v:null || s:req.done
    return
  endif
  let l:s = reltimefloat(reltime(a:start))
  call s:progress(printf('llm: %s, %.0f s: %s', s:req_what, l:s,
    \ s:last_log_line(&columns - 40)))
  call timer_start(1000, function('s:req_progress', [a:start]))
endfunction

function! s:post_done(ctx, result) abort
  let s:req_started = 0
  if has_key(a:result, 'error')
    let l:why = {'connect': 'could not connect; is the server running?',
      \ 'timeout': 'the request timed out (g:llm_timeout)',
      \ 'closed': 'the server closed the connection without answering'}[a:result.error]
    call add(s:log, 'llm: ' . l:why)
    if a:result.error ==# 'connect' && s:state ==# 'external' && exists('s:last_fn')
      " The server we were sharing has gone (its Vim exited): start our
      " own and redo the request when it is up.
      let s:state = 'stopped'
      call s:say('llm: the shared server is gone; starting one')
      call s:when_ready(s:last_fn)
      return
    endif
    echohl ErrorMsg | echomsg 'llm: ' . l:why . ' (:LlmStatus, :LlmLog)' | echohl None
    return
  endif
  let l:text = a:result.body
  try
    let l:resp = a:ctx.Progress isnot v:null && l:text =~# '^\%(\s*\n\)*data:'
      \ ? s:sse_merge(s:sse_events(l:text)) : json_decode(l:text)
  catch
    call add(s:log, 'llm: bad response (HTTP ' . a:result.status . '): ' . strpart(l:text, 0, 400))
    echohl ErrorMsg | echomsg 'llm: bad response: ' . strpart(l:text, 0, 120) . ' (see :LlmLog)' | echohl None
    return
  endtry
  if type(l:resp) != v:t_dict
    call add(s:log, 'llm: unexpected response (HTTP ' . a:result.status . '): ' . strpart(l:text, 0, 400))
    echohl ErrorMsg | echomsg 'llm: unexpected response: ' . strpart(l:text, 0, 160) . ' (see :LlmLog)' | echohl None
    return
  endif
  if has_key(l:resp, 'error')
    let l:e = l:resp.error
    echohl ErrorMsg | echomsg 'llm: server error: ' . (type(l:e) == v:t_dict ? get(l:e, 'message', string(l:e)) : string(l:e)) | echohl None
    return
  endif
  let l:t = get(l:resp, 'timings', {})
  " tokens_cached is the whole context after the request, prompt_n the part
  " that had to be processed now; the difference was reused from the cache.
  let s:last = {'prompt_n': get(l:t, 'prompt_n', 0),
    \ 'total': get(l:resp, 'tokens_cached', 0),
    \ 'cached': max([0, get(l:resp, 'tokens_cached', 0) - get(l:t, 'prompt_n', 0) - get(l:t, 'predicted_n', 0)]),
    \ 'outcome': '', 'content': strpart(get(l:resp, 'content', ''), 0, 200),
    \ 'predicted_n': get(l:t, 'predicted_n', 0), 'predicted_per_second': get(l:t, 'predicted_per_second', 0.0),
    \ 'total_ms': reltimefloat(reltime(a:ctx.start)) * 1000}
  call s:guarded(a:ctx.Cb, [l:resp])
endfunction

" Run Fn now if the server is ready, otherwise start it and run Fn when it
" becomes ready.
function! s:when_ready(Fn) abort
  let s:last_fn = a:Fn
  if s:state ==# 'ready' || s:state ==# 'external'
    call s:guarded(a:Fn, [])
  elseif s:state ==# 'starting'
    call add(s:pending, a:Fn)
    call s:progress(printf('llm: the server is still loading (%d s); this runs when it is ready', localtime() - s:poll_started))
  else
    " Queue first: the probe may finish synchronously inside llm#start().
    call add(s:pending, a:Fn)
    if !llm#start()
      let s:pending = []
    endif
  endif
endfunction

" ------------------------------------------------------------- context

" What the model sees: text before the cursor, text after it, and chunks
" from places you have been recently (jump list, other buffers of the same
" filetype), so it knows what you are working on.
" The suffix is the expensive part of a request: it comes after the edit
" point in the prompt, so the server processes it again every time, while
" the prefix and the extra chunks stay cached. Keep it short.
" Lines are the unit, but a file of paragraph-long lines (prose, Typst,
" LaTeX) would make 200 lines enormous, so both sides are also capped by
" characters. Only these few lines are ever read, so file size does not
" matter; the server trims what still does not fit its context.
function! s:context(suffix_lines) abort
  let l:lnum = line('.')
  let l:col = col('.')
  let l:line = getline('.')
  let l:before = l:col > 1 ? l:line[: l:col - 2] : ''
  let l:after = l:line[l:col - 1 :]
  let l:prefix = getline(max([1, l:lnum - s:opt('prefix_lines', 200)]), l:lnum - 1) + [l:before]
  let l:suffix = [l:after] + getline(l:lnum + 1, min([line('$'), l:lnum + a:suffix_lines]))
  let l:prefix = join(l:prefix, "\n")
  let l:suffix = join(l:suffix, "\n")
  let l:budget = s:opt('prefix_chars', 12000)
  if len(l:prefix) > l:budget
    " Keep the end, from a line boundary.
    let l:prefix = substitute(strpart(l:prefix, len(l:prefix) - l:budget), '^[^\n]*\n', '', '')
  endif
  let l:budget = s:opt('suffix_chars', 2000)
  if len(l:suffix) > l:budget
    let l:suffix = substitute(strpart(l:suffix, 0, l:budget), '\n[^\n]*$', '', '')
  endif
  return {'prefix': l:prefix, 'suffix': l:suffix,
    \ 'extra': s:extra_chunks(bufnr('%'), l:lnum), 'lnum': l:lnum, 'col': l:col}
endfunction

" Chunks from places you have been recently. They go first in the prompt,
" so their order must not change between requests or the cache is lost:
" they are chosen by recency but sent in a fixed buffer/line order.
function! s:extra_chunks(curbuf, lnum) abort
  let l:budget = s:opt('extra_chars', 6000)
  let l:span = s:opt('extra_chunk_lines', 30)
  let l:max = s:opt('extra_chunks', 6)
  let l:seen = {}
  let l:picked = []
  let l:total = 0
  let l:spots = []
  " Most recent jumps first.
  for l:j in reverse(copy(getjumplist()[0]))
    call add(l:spots, [l:j.bufnr, l:j.lnum])
  endfor
  " Then other loaded buffers of the same filetype, at their cursor lines.
  for l:b in getbufinfo({'bufloaded': 1, 'buflisted': 1})
    if l:b.bufnr != a:curbuf && getbufvar(l:b.bufnr, '&filetype') ==# &filetype
      call add(l:spots, [l:b.bufnr, l:b.lnum])
    endif
  endfor
  for [l:bufnr, l:at] in l:spots
    if !bufloaded(l:bufnr) || getbufvar(l:bufnr, '&buftype') !=# ''
      continue
    endif
    " Skip what the prefix already covers.
    if l:bufnr == a:curbuf && abs(l:at - a:lnum) <= s:opt('prefix_lines', 200)
      continue
    endif
    let l:start = (max([1, l:at - l:span / 2]) - 1) / l:span * l:span + 1
    let l:key = l:bufnr . ':' . l:start
    if has_key(l:seen, l:key)
      continue
    endif
    let l:seen[l:key] = 1
    let l:text = join(getbufline(l:bufnr, l:start, l:start + l:span - 1), "\n")
    if empty(trim(l:text))
      continue
    endif
    let l:total += len(l:text)
    if l:total > l:budget || len(l:picked) >= l:max
      break
    endif
    call add(l:picked, [l:bufnr, l:start, l:text])
  endfor
  call sort(l:picked, {a, b -> a[0] != b[0] ? a[0] - b[0] : a[1] - b[1]})
  return map(l:picked, '{"filename": fnamemodify(bufname(v:val[0]), ":t"), "text": v:val[2]}')
endfunction

" Request body for the model: /infill for fill-in-the-middle models,
" /completion (prefix only) for plain ones.
" s:request(ctx, n_predict, Cb, what [, extra params [, Progress]])
function! s:request(ctx, n_predict, Cb, what, ...) abort
  let l:common = {'n_predict': a:n_predict, 'cache_prompt': v:true,
    \ 'temperature': s:opt('temperature', 0.1), 'top_k': 40, 'top_p': 0.9,
    \ 'repeat_penalty': s:opt('repeat_penalty', 1.1), 'repeat_last_n': 128,
    \ 't_max_prompt_ms': s:opt('prompt_ms', -1), 't_max_predict_ms': s:opt('predict_ms', 4000)}
  if a:0
    call extend(l:common, a:1)
  endif
  let l:more = a:0 > 1 ? [a:2] : []
  if s:model_is_fim()
    call call('s:post', ['/infill', extend(l:common, {'input_prefix': a:ctx.prefix,
      \ 'input_suffix': a:ctx.suffix, 'input_extra': a:ctx.extra}), a:Cb, a:what] + l:more)
  else
    let l:head = join(map(copy(a:ctx.extra), '"// " . v:val.filename . "\n" . v:val.text'), "\n\n")
    call call('s:post', ['/completion', extend(l:common, {'prompt': (empty(l:head) ? '' : l:head . "\n\n") . a:ctx.prefix}), a:Cb, a:what] + l:more)
  endif
endfunction

" One line describing a context, for messages.
function! s:describe(ctx) abort
  let l:chars = len(a:ctx.prefix) + len(a:ctx.suffix)
  let l:extra = 0
  for l:c in a:ctx.extra
    let l:extra += len(l:c.text)
  endfor
  return printf('%d chars here%s', l:chars,
    \ empty(a:ctx.extra) ? '' : printf(' + %d chunk%s (%d chars) from recent places',
    \ len(a:ctx.extra), len(a:ctx.extra) == 1 ? '' : 's', l:extra))
endfunction

" ------------------------------------------------------------- warm-up

" Start the server if needed and prime its prompt cache with the context
" around the cursor, so the first real completion in this file only has
" to process what changed since. Works from Normal mode.
function! llm#warm() abort
  call s:when_ready(function('s:warm_now'))
endfunction

function! s:warm_now() abort
  let l:ctx = s:context(s:opt('block_suffix_lines', 30))
  call s:say(printf('llm: priming with %s: %s ...', fnamemodify(bufname('%'), ':t'), s:describe(l:ctx)))
  call s:request(l:ctx, 1, function('s:warm_done'), 'priming')
endfunction

function! s:warm_done(resp) abort
  let l:t = get(a:resp, 'timings', {})
  let s:last.outcome = 'warm'
  call s:say(printf('llm: warm in %.1f s; %d context tokens cached (%d were already)',
    \ get(s:last, 'total_ms', 0.0) / 1000, get(s:last, 'total', 0), get(s:last, 'cached', 0)))
endfunction

" --------------------------------------------------- word / phrase / line

function! llm#complete_menu() abort
  call llm#dismiss()
  call s:when_ready(function('s:menu_now'))
endfunction

function! s:menu_now() abort
  if mode() !~# '^i'
    call s:say('llm: ready now, but you left Insert mode; ask again')
    return
  endif
  let l:ctx = s:context(s:opt('menu_suffix_lines', 8))
  echo 'llm: thinking ...'
  " A few words' worth of tokens; the menu uses only the first line, and
  " every token costs generation time.
  call s:request(l:ctx, s:opt('menu_tokens', 12), function('s:menu_show', [l:ctx]), 'completing',
    \ {'t_max_predict_ms': s:opt('menu_ms', 1500)})
endfunction

function! s:menu_show(ctx, resp) abort
  if mode() !~# '^i' || line('.') != a:ctx.lnum || col('.') != a:ctx.col
    return
  endif
  let l:text = get(a:resp, 'content', '')
  let l:first = matchstr(l:text, '^[^\n]*')
  if empty(trim(l:first))
    " The model wants to end this line. Offer its next line as ghost text
    " instead, so CTRL-Y still takes it.
    let l:rest = substitute(l:text, '^\%(\s*\n\)*', '', '')
    let l:next = matchstr(l:rest, '^[^\n]*')
    if empty(trim(l:next)) || l:rest is# l:text
      let s:last.outcome = 'empty'
      echo 'llm: no suggestion'
      return
    endif
    call s:block_show(a:ctx, {'content': "\n" . l:next})
    return
  endif
  let l:items = []
  let l:seen = {}
  let l:word = matchstr(l:first, '^\s*\S\+')
  let l:phrase = matchstr(l:first, '^.\{-}[,.;:)\]}]\ze')
  for [l:label, l:w] in [['word', l:word], ['phrase', l:phrase], ['line', l:first]]
    let l:w = substitute(l:w, '\s\+$', '', '')
    if !empty(l:w) && !has_key(l:seen, l:w)
      let l:seen[l:w] = 1
      call add(l:items, {'word': l:w, 'menu': 'llm ' . l:label, 'icase': 0, 'dup': 1})
    endif
  endfor
  " Clear "thinking ..." before Vim's own completion message, or the two
  " stack up into a hit-enter prompt.
  redraw
  echo ''
  let s:last.outcome = 'menu'
  call complete(a:ctx.col, l:items)
endfunction

" ----------------------------------------------------------- block ghost

function! llm#complete_block() abort
  call llm#dismiss()
  call s:when_ready(function('s:block_now'))
endfunction

function! s:block_now() abort
  if mode() !~# '^i'
    call s:say('llm: ready now, but you left Insert mode; ask again')
    return
  endif
  let l:ctx = s:context(s:opt('block_suffix_lines', 30))
  echo 'llm: thinking ...'
  " Streamed: the ghost text grows as the model writes, and CTRL-Y can
  " take what is there at any moment.
  call s:request(l:ctx, s:opt('block_tokens', 64), function('s:block_show', [l:ctx]), 'writing a block',
    \ {}, function('s:block_stream', [l:ctx]))
endfunction

" The lines a block reply amounts to, cut where they stop being useful
" and capped at g:llm_block_max_lines. Also says whether the cap was hit.
function! s:block_lines(ctx, text) abort
  let l:lines = s:trim_block(split(substitute(a:text, '\n\+$', '', ''), "\n", 1), a:ctx)
  let l:max = s:opt('block_max_lines', 8)
  let l:capped = len(l:lines) > l:max
  return [l:capped ? l:lines[: l:max - 1] : l:lines, l:capped]
endfunction

" Partial reply while streaming.
function! s:block_stream(ctx, resp) abort
  if mode() !~# '^i' || line('.') != a:ctx.lnum || col('.') != a:ctx.col
    call s:http_cancel(s:req)
    return
  endif
  let [l:lines, l:capped] = s:block_lines(a:ctx, get(a:resp, 'content', ''))
  if empty(l:lines) || empty(trim(join(l:lines, "\n")))
    return
  endif
  call s:ghost_render(a:ctx, l:lines)
  if l:capped
    " Enough lines: stop the model here rather than pay for more.
    call s:http_cancel(s:req)
    let s:last = {'outcome': 'block', 'prompt_n': 0, 'cached': 0, 'total': 0, 'predicted_n': 0,
      \ 'predicted_per_second': 0.0, 'content': strpart(get(a:resp, 'content', ''), 0, 200),
      \ 'total_ms': reltimefloat(reltime(s:req_started)) * 1000}
    let s:req_started = 0
    call s:ghost_message(l:lines)
  endif
endfunction

" The complete reply.
function! s:block_show(ctx, resp) abort
  if mode() !~# '^i' || line('.') != a:ctx.lnum || col('.') != a:ctx.col
    return
  endif
  let [l:lines, l:capped] = s:block_lines(a:ctx, get(a:resp, 'content', ''))
  if empty(l:lines) || empty(trim(join(l:lines, "\n")))
    call llm#dismiss()
    let s:last.outcome = 'empty'
    echo 'llm: no suggestion'
    return
  endif
  let s:last.outcome = 'block'
  call s:ghost_render(a:ctx, l:lines)
  call s:ghost_message(l:lines)
endfunction

function! s:ghost_message(lines) abort
  call s:progress(printf('llm: %d line%s in %.1f s; CTRL-Y accepts, CTRL-E dismisses',
    \ len(a:lines), len(a:lines) == 1 ? '' : 's', get(s:last, 'total_ms', 0.0) / 1000))
endfunction

" Show lines as ghost text at the cursor and below it, replacing what was
" shown before. The keys are the same as Vim's completion menu: CTRL-Y
" takes it, CTRL-E drops it; typing or moving drops it too.
function! s:ghost_render(ctx, lines) abort
  if empty(prop_type_get('llm_ghost'))
    call prop_type_add('llm_ghost', {'highlight': 'LlmGhost'})
  endif
  let l:fresh = empty(s:ghost)
  if !l:fresh
    for l:id in s:ghost.ids
      silent! call prop_remove({'id': l:id, 'bufnr': s:ghost.bufnr})
    endfor
  endif
  let l:ids = []
  call add(l:ids, prop_add(a:ctx.lnum, a:ctx.col, {'type': 'llm_ghost', 'text': empty(a:lines[0]) ? ' ' : a:lines[0]}))
  for l:l in a:lines[1:]
    call add(l:ids, prop_add(a:ctx.lnum, 0, {'type': 'llm_ghost', 'text': empty(l:l) ? ' ' : l:l, 'text_align': 'below'}))
  endfor
  let s:ghost = {'bufnr': bufnr('%'), 'lnum': a:ctx.lnum, 'col': a:ctx.col, 'lines': a:lines, 'ids': l:ids}
  if l:fresh
    inoremap <buffer> <silent> <C-Y> <Cmd>call llm#accept()<CR>
    inoremap <buffer> <silent> <C-E> <Cmd>call llm#dismiss()<CR>
    augroup llm_ghost
      autocmd!
      autocmd InsertCharPre,CursorMovedI,InsertLeave,BufLeave,TextChangedI <buffer> call llm#dismiss()
    augroup END
  endif
  redraw
endfunction

" Cut a generated block where it stops being useful: when it starts
" repeating a line it just produced (small models loop), or when it starts
" reproducing the text that already follows the cursor.
function! s:trim_block(lines, ctx) abort
  let l:next = matchstr(a:ctx.suffix, '\n\zs[^\n]*\S[^\n]*')
  let l:next = trim(l:next)
  let l:out = []
  let l:prev = ''
  for l:l in a:lines
    let l:t = trim(l:l)
    if !empty(l:t) && l:t ==# l:prev
      break
    endif
    if !empty(l:next) && l:t ==# l:next && !empty(l:out)
      break
    endif
    call add(l:out, l:l)
    let l:prev = l:t
  endfor
  while !empty(l:out) && empty(trim(l:out[-1]))
    call remove(l:out, -1)
  endwhile
  return l:out
endfunction

function! llm#dismiss() abort
  " A block still streaming in is no longer wanted either.
  if s:req isnot v:null && !s:req.done && s:req_what ==# 'writing a block'
    call s:http_cancel(s:req)
    let s:req_started = 0
  endif
  if empty(s:ghost)
    return
  endif
  let l:g = s:ghost
  let s:ghost = {}
  augroup llm_ghost
    autocmd!
  augroup END
  if bufexists(l:g.bufnr)
    for l:id in l:g.ids
      silent! call prop_remove({'id': l:id, 'bufnr': l:g.bufnr})
    endfor
    silent! iunmap <buffer> <C-Y>
    silent! iunmap <buffer> <C-E>
  endif
endfunction

function! llm#accept() abort
  if empty(s:ghost) || s:ghost.bufnr != bufnr('%')
    return
  endif
  let l:g = s:ghost
  call llm#dismiss()
  let l:line = getline(l:g.lnum)
  let l:before = l:g.col > 1 ? l:line[: l:g.col - 2] : ''
  let l:after = l:line[l:g.col - 1 :]
  let l:first = l:before . l:g.lines[0]
  if len(l:g.lines) == 1
    call setline(l:g.lnum, l:first . l:after)
    call cursor(l:g.lnum, len(l:first) + 1)
  else
    let l:last = l:g.lines[-1]
    call setline(l:g.lnum, l:first)
    call append(l:g.lnum, l:g.lines[1:-2] + [l:last . l:after])
    call cursor(l:g.lnum + len(l:g.lines) - 1, len(l:last) + 1)
  endif
endfunction

" Ghost text: the colour of text inserted by completion when Vim has it.
execute 'highlight default link LlmGhost' hlexists('ComplMatchIns') ? 'ComplMatchIns' : 'Comment'
