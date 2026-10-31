" Lean 4: the goal window. A read-only window that shows the tactic state
" at the cursor, the type expected there, and Lean's messages for the line,
" asked of Lean's language server as the cursor moves. See |lean-goal|.
"
" The server is "lake serve" in a Lake project and "lean --server" outside
" one, a job spoken to over its stdin and stdout in Vim's "lsp" channel
" mode, which does the Content-Length framing and the JSON. One server per
" project root, started when the window first needs it, never at startup.
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" key (project root, or '' outside a project) ->
"   job, ready, docs {bufnr: {uri, version, tick}}, uris {uri: bufnr}, stderr
let s:servers = {}
" key -> why the server is not to be started again without :LeanRestart.
let s:dead = {}
" bufnr -> the diagnostics Lean last published for it.
let s:diagnostics = {}
" What the window shows: where it was asked for, and the answers.
let s:shown = {'bufnr': 0, 'lnum': 0, 'goals': v:null, 'term': v:null, 'note': ''}
let s:goalbuf = -1
let s:seq = 0
let s:pending = 0
let s:busy = 0
let s:timer = -1
let s:busytimer = -1
let s:name = '[Lean Goal]'

" ---------------------------------------------------------------------------
" The window

function! s:visible() abort
  return s:goalbuf > 0 && bufwinid(s:goalbuf) != -1
endfunction

function! lean#goal#open() abort
  if s:visible()
    return
  endif
  if !has('channel') || !has('job') || !exists('*utf16idx')
    echohl ErrorMsg | echomsg 'LeanGoal: this Vim has no lsp channels' | echohl None
    return
  endif
  let l:source = win_getid()
  if s:goalbuf < 1 || !bufexists(s:goalbuf)
    let s:goalbuf = bufadd(s:name)
    call bufload(s:goalbuf)
    call setbufvar(s:goalbuf, '&buftype', 'nofile')
    call setbufvar(s:goalbuf, '&bufhidden', 'hide')
    call setbufvar(s:goalbuf, '&swapfile', 0)
    call setbufvar(s:goalbuf, '&buflisted', 0)
    call setbufvar(s:goalbuf, '&modifiable', 0)
  endif
  " Beside the text when there is room for both, under it otherwise.
  let l:where = get(g:, 'lean_goal_position', &columns >= 130 ? 'right' : 'below')
  if l:where ==# 'right'
    execute 'noautocmd botright vertical sbuffer' s:goalbuf
    execute 'vertical resize' get(g:, 'lean_goal_width', max([40, &columns / 3]))
    setlocal winfixwidth
  else
    execute 'noautocmd botright sbuffer' s:goalbuf
    execute 'resize' get(g:, 'lean_goal_height', 12)
    setlocal winfixheight
  endif
  " A goal is read whole: long hypotheses wrap instead of running off.
  setlocal wrap linebreak nonumber norelativenumber nospell nolist nocursorline
  setlocal signcolumn=no foldcolumn=0
  if &l:filetype !=# 'leangoal'
    setlocal filetype=leangoal
  endif
  noautocmd call win_gotoid(l:source)

  augroup lean_goal
    autocmd!
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI,TextChangedP *
      \ call s:schedule()
    autocmd BufEnter,WinEnter,InsertEnter,InsertLeave * call s:schedule()
    autocmd BufUnload * call s:forget(str2nr(expand('<abuf>')))
    autocmd QuitPre * call s:quitting()
    autocmd VimLeavePre * call lean#goal#stop()
  augroup END
  call s:render()
  call s:schedule()
endfunction

function! lean#goal#close() abort
  if s:goalbuf < 1
    return
  endif
  for l:winid in win_findbuf(s:goalbuf)
    call win_execute(l:winid, 'noautocmd close')
  endfor
endfunction

" :q in the last window beside the goal window means "I am done here", not
" "leave me with the goal window".
function! s:quitting() abort
  if winnr('$') == 2 && s:visible() && bufnr('') != s:goalbuf
    call lean#goal#close()
  endif
endfunction

function! lean#goal#toggle() abort
  if s:visible()
    call lean#goal#close()
  else
    call lean#goal#open()
  endif
endfunction

" The headings are those of Lean's own infoview. What is absent is left out,
" so in the middle of a proof the window is the goals and nothing else.
function! s:lines() abort
  let l:lines = []
  if s:busy
    call add(l:lines, 'Lean is working …')
  endif
  if !empty(s:shown.note)
    call extend(l:lines, (empty(l:lines) ? [] : ['']) + split(s:shown.note, "\n"))
  endif
  if type(s:shown.goals) == v:t_list
    let l:count = len(s:shown.goals)
    call extend(l:lines, (empty(l:lines) ? [] : [''])
      \ + [l:count == 0 ? 'No goals' : l:count == 1 ? 'Tactic state' : 'Tactic state (' . l:count . ' goals)'])
    for l:i in range(l:count)
      call extend(l:lines, (l:i ? [''] : []) + split(s:shown.goals[l:i], "\n"))
    endfor
  endif
  if type(s:shown.term) == v:t_string
    call extend(l:lines, (empty(l:lines) ? [] : ['']) + ['Expected type'] + split(s:shown.term, "\n"))
  endif
  let l:messages = []
  for l:d in get(s:diagnostics, s:shown.bufnr, [])
    let l:range = get(l:d, 'fullRange', l:d.range)
    if l:range.start.line <= s:shown.lnum - 1 && s:shown.lnum - 1 <= l:range.end.line
      call add(l:messages, printf('%d:%d %s', l:d.range.start.line + 1, l:d.range.start.character + 1,
        \ get(['error', 'error', 'warning', 'info', 'hint'], get(l:d, 'severity', 1), 'info')))
      call extend(l:messages, split(l:d.message, "\n"))
    endif
  endfor
  if !empty(l:messages)
    call extend(l:lines, (empty(l:lines) ? [] : ['']) + ['Messages'] + l:messages)
  endif
  return empty(l:lines) ? ['No goal here'] : l:lines
endfunction

function! s:render() abort
  if s:goalbuf < 1 || !bufloaded(s:goalbuf)
    return
  endif
  let l:lines = s:lines()
  if l:lines ==# getbufline(s:goalbuf, 1, '$')
    return
  endif
  call setbufvar(s:goalbuf, '&modifiable', 1)
  silent call deletebufline(s:goalbuf, 1, '$')
  call setbufline(s:goalbuf, 1, l:lines)
  call setbufvar(s:goalbuf, '&modifiable', 0)
  for l:winid in win_findbuf(s:goalbuf)
    call win_execute(l:winid, 'noautocmd normal! gg0')
  endfor
endfunction

" ---------------------------------------------------------------------------
" The server

function! s:key(bufnr) abort
  return getbufvar(a:bufnr, 'lean_root', '')
endfunction

function! s:uri(path) abort
  let l:path = substitute(fnamemodify(a:path, ':p'), '\\', '/', 'g')
  let l:path = substitute(l:path, '[^A-Za-z0-9/._~:-]', '\=s:percent(submatch(0))', 'g')
  return (l:path[0] ==# '/' ? 'file://' : 'file:///') . l:path
endfunction

function! s:percent(char) abort
  return join(map(range(strlen(a:char)), 'printf("%%%02X", char2nr(a:char[v:val]))'), '')
endfunction

" The server for a buffer, started if there is none. {} when there cannot be
" one, with the reason left in s:shown.note.
function! s:server(bufnr) abort
  let l:key = s:key(a:bufnr)
  if has_key(s:servers, l:key)
    return s:servers[l:key]
  endif
  if has_key(s:dead, l:key)
    let s:shown.note = s:dead[l:key]
    return {}
  endif
  if !empty(l:key) && executable('lake')
    let [l:command, l:cwd] = [['lake', 'serve', '--'], l:key]
  elseif executable('lean')
    let [l:command, l:cwd] = [['lean', '--server'], fnamemodify(bufname(a:bufnr), ':p:h')]
  else
    let s:dead[l:key] = 'lean is not on the PATH'
    let s:shown.note = s:dead[l:key]
    return {}
  endif
  let l:server = {'key': l:key, 'ready': 0, 'docs': {}, 'uris': {}, 'stderr': [], 'stopping': 0}
  let l:server.job = job_start(l:command, {
    \ 'in_mode': 'lsp', 'out_mode': 'lsp', 'err_mode': 'nl', 'cwd': l:cwd, 'noblock': 1,
    \ 'out_cb': function('s:incoming', [l:key]),
    \ 'err_cb': function('s:stderr', [l:key]),
    \ 'exit_cb': function('s:exited', [l:key]),
    \ })
  if job_status(l:server.job) !=# 'run'
    let s:dead[l:key] = 'Could not start ' . join(l:command)
    let s:shown.note = s:dead[l:key]
    return {}
  endif
  let s:servers[l:key] = l:server
  call s:send(l:server, {'method': 'initialize', 'params': {
    \ 'processId': getpid(), 'rootUri': empty(l:key) ? v:null : s:uri(l:key),
    \ 'capabilities': {}}}, {'callback': function('s:initialized', [l:key])})
  return l:server
endfunction

" Everything said to a server is said here. A server that has just died
" still has a channel for a moment, and writing to it is an error (E631)
" that would otherwise surface in the middle of a cursor movement. Its exit
" callback is what reports the death.
function! s:send(server, message, ...) abort
  try
    if a:0
      call ch_sendexpr(a:server.job, a:message, a:1)
    else
      call ch_sendexpr(a:server.job, a:message)
    endif
  catch /^Vim\%((\a\+)\)\=:E\d\+/
  endtry
endfunction

function! s:initialized(key, channel, message) abort
  if !has_key(s:servers, a:key)
    return
  endif
  call s:send(s:servers[a:key], {'method': 'initialized', 'params': {}})
  let s:servers[a:key].ready = 1
  call s:schedule()
endfunction

" Whatever the server sends that is not the answer to a request.
function! s:incoming(key, channel, message) abort
  if !has_key(s:servers, a:key) || type(a:message) != v:t_dict
    return
  endif
  let l:server = s:servers[a:key]
  let l:method = get(a:message, 'method', '')
  if has_key(a:message, 'id') && !empty(l:method)
    " A request of its own (register a file watcher, refresh the inlay
    " hints). There is nothing to do for any of them, but it wants an answer.
    " Written out by hand: ch_sendexpr() takes a number for the id and
    " nothing else, and Lean's first request is "register_lean_watcher".
    let l:reply = json_encode({'jsonrpc': '2.0', 'id': a:message.id, 'result': v:null})
    try
      call ch_sendraw(l:server.job, 'Content-Length: ' . strlen(l:reply) . "\r\n\r\n" . l:reply)
    catch /^Vim\%((\a\+)\)\=:E\d\+/
    endtry
  elseif l:method ==# 'textDocument/publishDiagnostics'
    let l:bufnr = get(l:server.uris, a:message.params.uri, 0)
    if l:bufnr
      let s:diagnostics[l:bufnr] = a:message.params.diagnostics
      if l:bufnr == s:shown.bufnr
        call s:render()
      endif
    endif
  endif
endfunction

function! s:stderr(key, channel, line) abort
  if has_key(s:servers, a:key)
    call add(s:servers[a:key].stderr, a:line)
  endif
endfunction

" A server that stops by itself is not started again by the next cursor
" movement: if it cannot run it would be started on every one of them.
function! s:exited(key, job, status) abort
  if !has_key(s:servers, a:key) || s:servers[a:key].job isnot a:job
    return
  endif
  let l:server = remove(s:servers, a:key)
  for l:bufnr in keys(l:server.docs)
    silent! call remove(s:diagnostics, l:bufnr)
  endfor
  if l:server.stopping
    return
  endif
  let s:dead[a:key] = join(['The Lean server stopped (exit ' . a:status . '). :LeanRestart starts it again.']
    \ + l:server.stderr[-8:], "\n")
  if s:key(s:shown.bufnr) ==# a:key
    let [s:shown.goals, s:shown.term, s:shown.note, s:busy] = [v:null, v:null, s:dead[a:key], 0]
    call s:render()
  endif
endfunction

function! lean#goal#stop() abort
  for l:server in values(s:servers)
    let l:server.stopping = 1
    call s:send(l:server, {'method': 'shutdown'}, {'callback': {-> 0}})
    call s:send(l:server, {'method': 'exit'})
    silent! call job_stop(l:server.job)
  endfor
  let [s:servers, s:dead, s:diagnostics] = [{}, {}, {}]
  let [s:shown.goals, s:shown.term, s:shown.note, s:busy] = [v:null, v:null, '', 0]
  let s:seq += 1
  call s:render()
endfunction

function! lean#goal#restart() abort
  call lean#goal#stop()
  call s:schedule()
endfunction

" Tell the server what the buffer holds now: all of it, when it has changed
" since the server was last told.
function! s:sync(server, bufnr) abort
  let l:tick = getbufvar(a:bufnr, 'changedtick')
  let l:text = join(getbufline(a:bufnr, 1, '$'), "\n") . "\n"
  if !has_key(a:server.docs, a:bufnr)
    let l:doc = {'uri': s:uri(bufname(a:bufnr)), 'version': 1, 'tick': l:tick}
    let a:server.docs[a:bufnr] = l:doc
    let a:server.uris[l:doc.uri] = a:bufnr
    call s:send(a:server, {'method': 'textDocument/didOpen', 'params': {'textDocument':
      \ {'uri': l:doc.uri, 'languageId': 'lean', 'version': 1, 'text': l:text}}})
  elseif a:server.docs[a:bufnr].tick != l:tick
    let l:doc = a:server.docs[a:bufnr]
    let [l:doc.version, l:doc.tick] = [l:doc.version + 1, l:tick]
    call s:send(a:server, {'method': 'textDocument/didChange', 'params': {
      \ 'textDocument': {'uri': l:doc.uri, 'version': l:doc.version},
      \ 'contentChanges': [{'text': l:text}]}})
  endif
  return a:server.docs[a:bufnr]
endfunction

" A buffer is going away: the server can let go of it.
function! s:forget(bufnr) abort
  silent! call remove(s:diagnostics, a:bufnr)
  for l:server in values(s:servers)
    if has_key(l:server.docs, a:bufnr)
      let l:doc = remove(l:server.docs, a:bufnr)
      silent! call remove(l:server.uris, l:doc.uri)
      call s:send(l:server, {'method': 'textDocument/didClose',
        \ 'params': {'textDocument': {'uri': l:doc.uri}}})
    endif
  endfor
endfunction

" ---------------------------------------------------------------------------
" Asking

" Every cursor movement comes through here. The question goes out once the
" cursor has rested, so holding j down asks once and not forty times.
function! s:schedule() abort
  if &filetype !=# 'lean' || !s:visible()
    return
  endif
  call timer_stop(s:timer)
  let s:timer = timer_start(get(g:, 'lean_goal_delay', 80), function('s:ask'))
endfunction

function! s:ask(timer) abort
  if &filetype !=# 'lean' || !s:visible() || empty(bufname(''))
    return
  endif
  let l:bufnr = bufnr('')
  let s:seq += 1
  let s:shown.note = ''
  let l:server = s:server(l:bufnr)
  if empty(l:server) || !l:server.ready
    let [s:shown.bufnr, s:shown.lnum, s:shown.goals, s:shown.term] = [l:bufnr, line('.'), v:null, v:null]
    let s:busy = !empty(l:server)
    call s:render()
    return
  endif
  let l:doc = s:sync(l:server, l:bufnr)
  " Lean counts a column in UTF-16 code units.
  let l:character = utf16idx(getline('.'), col('.') - 1)
  let l:params = {'textDocument': {'uri': l:doc.uri}, 'position': {'line': line('.') - 1,
    \ 'character': l:character < 0 ? strutf16len(getline('.')) : l:character}}
  let l:asked = {'seq': s:seq, 'bufnr': l:bufnr, 'lnum': line('.'), 'left': 2,
    \ 'goals': v:null, 'term': v:null, 'note': ''}
  let s:pending = s:seq
  call s:send(l:server, {'method': '$/lean/plainGoal', 'params': l:params},
    \ {'callback': function('s:answer', [l:asked, 'goals'])})
  call s:send(l:server, {'method': '$/lean/plainTermGoal', 'params': l:params},
    \ {'callback': function('s:answer', [l:asked, 'term'])})
  " Lean answers when it has elaborated the file as far as the cursor. Say
  " so when that takes a while, over the state that is there until then.
  call timer_stop(s:busytimer)
  let s:busytimer = timer_start(400, function('s:working', [s:seq]))
endfunction

function! s:working(seq, timer) abort
  if a:seq == s:pending && !s:busy
    let s:busy = 1
    call s:render()
  endif
endfunction

" One of the two answers. Both are waited for, so the window changes once.
" An answer to a question that has since been asked again is dropped.
function! s:answer(asked, what, channel, message) abort
  if a:asked.seq != s:seq
    return
  endif
  if has_key(a:message, 'error')
    " -32801, the file changed under the request, and -32800, cancelled:
    " the question has been or will be asked again.
    if index([-32801, -32800], get(a:message.error, 'code', 0)) < 0
      let a:asked.note = 'Lean: ' . get(a:message.error, 'message', 'request failed')
    endif
  elseif type(get(a:message, 'result', v:null)) == v:t_dict
    let a:asked[a:what] = a:what ==# 'goals' ? get(a:message.result, 'goals', [])
      \ : get(a:message.result, 'goal', v:null)
  endif
  let a:asked.left -= 1
  if a:asked.left > 0
    return
  endif
  let [s:pending, s:busy] = [0, 0]
  call extend(s:shown, {'bufnr': a:asked.bufnr, 'lnum': a:asked.lnum, 'goals': a:asked.goals,
    \ 'term': a:asked.term, 'note': a:asked.note})
  call s:render()
endfunction

" For tests and for the curious: what the window is showing and to whom.
function! lean#goal#state() abort
  return {'shown': s:shown, 'busy': s:busy, 'dead': s:dead, 'bufnr': s:goalbuf,
    \ 'servers': map(copy(s:servers), '{"ready": v:val.ready, "status": job_status(v:val.job), "pid": job_info(v:val.job).process,'
    \   . ' "docs": map(values(v:val.docs), "v:val.uri"), "stderr": v:val.stderr}')}
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
