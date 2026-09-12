" One Matlab session, kept alive and spoken to over a loopback socket, so
" running something costs milliseconds instead of the five seconds Matlab
" needs to start. matlab/server.m and matlab/vimserver.m are the other half.
"
" This session is its own process with its own workspace. It does not share
" anything with a Matlab desktop you have open. It runs without the desktop
" but at an interactive prompt, which is what lets plugin/matlabdebug.vim
" stop it at a breakpoint and carry on talking to it; see
" |matlabdebug-workaround| for what that rests on.
"
" Requests are asynchronous underneath. Each one is tagged with an id, the
" reply comes back through a channel callback, and the debugger's events
" arrive the same way. matlabserver#eval_sync() waits on top of that for
" the callers that want an answer in hand (:Matlab, :make): it sleeps in
" small steps, and the callback fires during the sleep.

" vimfiles itself. Resolved here and not inside a function: <sfile> names the
" sourced script only at script level, and the running function inside one.
let s:root = expand('<sfile>:p:h:h')

let s:sentinel = '--MATLABSERVER-DONE--'
let s:begin = '--MATLABSERVER-BEGIN--'
let s:event = '--MATLABSERVER-EVENT--'
let s:frameline = '--MATLABSERVER-FRAME--'
" The command sent to see whether the session answers. Not "1": that is an
" expression, and every ping would set ans in the user's workspace.
let s:ping = "disp('')"
let s:job = v:null          " the matlab process running server.m
let s:ch = v:null           " the channel to it
let s:partial = ''          " the unfinished last line read from the channel
let s:seq = 0               " request ids
let s:requests = {}         " id -> request, until its reply is complete
let s:waiting = []          " requests not yet sent, in order
let s:current = v:null      " the request sent and not yet answered
let s:receiving = ''        " id named by the last BEGIN line
let s:frames = []           " frames of the stop event being received

function! s:dir() abort
  return s:root . '/matlab'
endfunction

function! s:port() abort
  return get(g:, 'matlabserver_port', 51763)
endfunction

" Seconds of quiet before the session shuts itself down. Enforced inside
" vimserver.m, so it holds even if Vim never gets to run its VimLeavePre.
function! s:idle() abort
  return get(g:, 'matlabserver_idle', 1800)
endfunction

function! s:program() abort
  let l:set = get(g:, 'matlabdoc_program', '')
  if !empty(l:set)
    return l:set
  endif
  let l:path = exepath('matlab')
  if !empty(l:path)
    return l:path
  endif
  let l:found = sort(glob('C:/Program Files/MATLAB/R*/bin/matlab.exe', 0, 1))
  return empty(l:found) ? '' : l:found[-1]
endfunction

function! s:err(msg) abort
  echohl ErrorMsg | echomsg 'matlabserver: ' . a:msg | echohl NONE
endfunction

function! s:warn(msg) abort
  echohl WarningMsg | echomsg 'matlabserver: ' . a:msg | echohl NONE
endfunction

" ------------------------------------------------------------ lifecycle

function! matlabserver#running() abort
  return s:job isnot v:null && job_status(s:job) ==# 'run'
endfunction

function! s:connect() abort
  if s:ch isnot v:null && ch_status(s:ch) ==# 'open'
    return 1
  endif
  " Raw mode and a callback: lines are split here. In nl mode a read
  " returning an empty string means either an empty line or nothing yet,
  " which is no way to keep a command's blank lines.
  let s:ch = ch_open('127.0.0.1:' . s:port(), {'mode': 'raw', 'waittime': 200,
    \ 'drop': 'never', 'callback': function('s:receive'),
    \ 'close_cb': function('s:closed')})
  let s:partial = ''
  return ch_status(s:ch) ==# 'open'
endfunction

function! s:disconnect() abort
  if s:ch isnot v:null
    silent! call ch_close(s:ch)
  endif
  let s:ch = v:null
  let s:partial = ''
endfunction

" The session is gone, or the connection is: every request still open gets
" an answer saying so, so that nothing waits on it.
function! s:fail_all(why) abort
  let l:open = values(s:requests) + s:waiting
  let s:requests = {}
  let s:waiting = []
  let s:current = v:null
  let s:receiving = ''
  let s:frames = []
  for l:req in l:open
    call s:complete(l:req, -1, [a:why])
  endfor
endfunction

function! s:closed(ch) abort
  if a:ch isnot s:ch
    return
  endif
  let s:ch = v:null
  call s:fail_all('the connection to the session closed')
endfunction

function! s:exited(job, status) abort
  " After :MatlabStop the job is already forgotten and the exit is expected;
  " only an exit nobody asked for is worth a message. Status 0 out of the
  " blue is the idle timeout in vimserver.m.
  if a:job isnot s:job
    return
  endif
  let s:job = v:null
  call s:disconnect()
  call s:fail_all('the Matlab session has ended')
  if exists('*matlabdebug#reset')
    call matlabdebug#reset()
  endif
  if a:status == 0
    echomsg printf('matlabserver: the Matlab session has ended (it closes itself after'
      \ . ' %d min idle); :MatlabStart brings it back', s:idle() / 60)
  else
    echomsg 'matlabserver: the Matlab session exited with status ' . a:status
      \ . '; see ' . s:dir() . '/server.log'
  endif
endfunction

function! matlabserver#start() abort
  if matlabserver#running()
    echo 'matlabserver: already running on port ' . s:port()
    return
  endif
  let l:exe = s:program()
  if empty(l:exe)
    call s:err('no matlab.exe found; set g:matlabdoc_program')
    return
  endif
  " Not -batch, though it was: a debugger stop needs a prompt to come back
  " to, and under -batch a dbquit ends the process. -r returns to an idle
  " prompt where a timer does the listening. -nodesktop on Windows would
  " still open a command window, and that window took the focus from Vim
  " as it appeared; -noDisplayDesktop keeps it from existing at all. The
  " price is that fprintf with arguments cannot write to stdout in that
  " mode, which vimserver.m avoids (everything you run is captured by
  " evalc and never touches stdout). Nothing is written to stdout in any
  " case, so -logfile. A preferences folder of its own keeps the setting
  " that stops Matlab opening its editor at every breakpoint from reaching
  " a desktop you use.
  let l:prefs = s:dir() . '/prefs'
  if !isdirectory(l:prefs)
    call mkdir(l:prefs, 'p')
  endif
  let l:cmd = [l:exe, '-sd', s:dir(), '-nodesktop', '-nosplash', '-noDisplayDesktop', '-wait',
    \ '-logfile', s:dir() . '/server.log',
    \ '-r', printf('try, server(%d, %d), catch e, disp(getReport(e)), exit(1), end',
    \              s:port(), s:idle())]
  " Under the watchdog so that a Vim that is killed rather than quit takes
  " the session with it; a normal exit does that by itself. It asks the
  " session to quit before killing it, and hides any window that appears
  " after all. See autoload/watchdog.vim.
  let s:job = job_start(watchdog#wrap(l:cmd,
    \ {'hide': 1, 'quit': ['127.0.0.1', s:port(), '0 quit']}),
    \ {'in_io': 'null', 'out_io': 'null', 'err_io': 'null',
    \  'env': {'MATLAB_PREFDIR': l:prefs}, 'exit_cb': function('s:exited')})
  if job_status(s:job) !=# 'run'
    let s:job = v:null
    call s:err('could not run ' . l:exe)
    return
  endif
  echo printf('matlabserver: starting Matlab, ready in a few seconds '
    \ . '(:MatlabStatus to check; it closes itself after %d min idle)',
    \ s:idle() / 60)
endfunction

" Make sure a session is up and answering, starting one and waiting for it if
" not. :make is synchronous, so blocking here is what the caller expects; the
" wait is only paid on the first :make of a Vim session.
function! matlabserver#ensure(timeout_ms) abort
  if matlabserver#eval_sync(s:ping, 500).ok
    return 1
  endif
  " Running and connected but not answering: it is busy with something
  " long, which is up, not down. Only a session that is not listening yet
  " is waited for below; pinging a busy one every 250 ms would leave a
  " queue of pings behind the command and end in a false alarm.
  if matlabserver#running() && s:ch isnot v:null && ch_status(s:ch) ==# 'open'
    return 1
  endif
  let l:start = reltime()
  let l:started = 0
  while reltimefloat(reltime(l:start)) * 1000 < a:timeout_ms
    " A session that has gone (idle timeout, crash) is only noticed when
    " its exit callback runs, which can be during the sleep below; so the
    " start is inside the loop, once.
    if !matlabserver#running()
      if l:started
        break
      endif
      call matlabserver#start()
      let l:started = 1
      if !matlabserver#running()
        return 0
      endif
    endif
    if matlabserver#eval_sync(s:ping, 500).ok
      redraw
      echo printf('matlabserver: ready after %.0f s',
        \ reltimefloat(reltime(l:start)))
      return 1
    endif
    " Until the session is listening the connect fails at once, so pace the
    " retries and say how long the wait has been rather than spin silently.
    sleep 250m
    redraw
    echo printf('matlabserver: starting Matlab, %.0f s ...',
      \ reltimefloat(reltime(l:start)))
  endwhile
  call s:err('the session did not come up within '
    \ . (a:timeout_ms / 1000) . ' s; see ' . s:dir() . '/server.log')
  return 0
endfunction

function! matlabserver#stop() abort
  let l:job = s:job
  let s:job = v:null
  let l:asked = 0
  if s:ch isnot v:null && ch_status(s:ch) ==# 'open'
    call ch_sendraw(s:ch, "0 quit\n")
    let l:asked = 1
  endif
  call s:disconnect()
  call s:fail_all('the session was stopped')
  if exists('*matlabdebug#reset')
    call matlabdebug#reset()
  endif
  if l:job isnot v:null && job_status(l:job) ==# 'run'
    if l:asked
      " Matlab leaves by itself once it reads the quit, a second or two of
      " JVM teardown later; nobody waits for that. Only a session too busy
      " to read it is cut off, so that a :MatlabStart meanwhile finds the
      " port free.
      call timer_start(5000, {-> job_status(l:job) ==# 'run' ? job_stop(l:job, 'kill') : 0})
    else
      call job_stop(l:job, 'kill')
    endif
  endif
  echo 'matlabserver: stopped'
endfunction

function! matlabserver#status() abort
  if !matlabserver#running()
    echo 'matlabserver: not running (:MatlabStart)'
    return
  endif
  let l:t = reltime()
  let l:out = matlabserver#eval_sync("fprintf('%s | %s', version('-release'), pwd)", 2000)
  let l:ms = reltimefloat(reltime(l:t)) * 1000
  echo printf('matlabserver: up on port %d, round trip %.0f ms, closes after %d min idle',
    \ s:port(), l:ms, s:idle() / 60)
  for l:line in l:out.lines
    if !empty(trim(l:line))
      echo '  ' . l:line
    endif
  endfor
endfunction

" ------------------------------------------------------------ requests

" Queue a request. {kind} is eval, dbg, stack, vars, break or clear (see the
" protocol at the top of vimserver.m); {Cb}, if not v:null, is called with
" the result dict {ok, status, lines, id} when the reply is complete. The
" request dict is returned so that a caller can watch it.
function! matlabserver#request(kind, text, Cb) abort
  let s:seq += 1
  let l:req = {'id': string(s:seq), 'kind': a:kind, 'text': a:text,
    \ 'lines': [], 'status': -1, 'done': 0, 'suspended': 0, 'cbs': []}
  if a:Cb isnot v:null
    call add(l:req.cbs, a:Cb)
  endif
  if !matlabserver#running()
    call s:complete(l:req, -1, ['matlabserver is not running; :MatlabStart'])
    return l:req
  endif
  " The protocol is one request per line. A newline inside the text would
  " be read as a second request, and every reply after that would answer
  " the wrong question.
  if a:text =~# "[\n\r]"
    call s:complete(l:req, -1, ['a command must be a single line'])
    return l:req
  endif
  if !s:connect()
    call s:complete(l:req, -1, ['could not connect on port ' . s:port()
      \ . '; Matlab may still be starting'])
    return l:req
  endif
  let s:requests[l:req.id] = l:req
  call add(s:waiting, l:req)
  call s:send_next()
  return l:req
endfunction

" Add a callback to a request still open, by id: the debugger uses this to
" learn when a run that stopped under it finally ends.
function! matlabserver#on_done(id, Cb) abort
  if has_key(s:requests, a:id)
    call add(s:requests[a:id].cbs, a:Cb)
    return 1
  endif
  return 0
endfunction

" One request on the wire at a time. The session serves them in order
" anyway; sending one at a time keeps every reply next to its request. A
" request stopped in the debugger is the exception: it is set aside as
" suspended so that the requests made at the K>> prompt can go.
function! s:send_next() abort
  if s:current isnot v:null || empty(s:waiting)
    return
  endif
  if s:ch is v:null || ch_status(s:ch) !=# 'open'
    call s:fail_all('the connection to the session closed')
    return
  endif
  let s:current = remove(s:waiting, 0)
  call ch_sendraw(s:ch, s:current.id . ' ' . s:current.kind . ' ' . s:current.text . "\n")
endfunction

function! s:complete(req, status, lines) abort
  let a:req.status = a:status
  let a:req.lines = a:lines
  let a:req.done = 1
  let l:res = {'ok': a:status == 0, 'status': a:status, 'lines': a:lines, 'id': a:req.id}
  for l:Cb in a:req.cbs
    call call(l:Cb, [l:res])
  endfor
endfunction

function! s:receive(ch, chunk) abort
  if a:ch isnot s:ch
    return
  endif
  let l:text = s:partial . a:chunk
  let l:nl = strridx(l:text, "\n")
  if l:nl < 0
    let s:partial = l:text
    return
  endif
  let s:partial = strpart(l:text, l:nl + 1)
  for l:line in split(strpart(l:text, 0, l:nl), "\n", 1)
    call s:line(l:line)
  endfor
endfunction

function! s:line(line) abort
  if a:line[0] !=# '-' || a:line !~# '^--MATLABSERVER-'
    if has_key(s:requests, s:receiving)
      call add(s:requests[s:receiving].lines, a:line)
    endif
    return
  endif
  if a:line =~# '^' . s:begin
    let s:receiving = matchstr(a:line, '\S\+$')
    return
  endif
  if a:line =~# '^' . s:frameline
    let l:parts = split(matchstr(a:line, ' \zs.*'), "\t", 1)
    if len(l:parts) >= 3
      call add(s:frames, {'line': str2nr(l:parts[0]), 'name': l:parts[1],
        \ 'file': join(l:parts[2:], "\t")})
    endif
    return
  endif
  if a:line =~# '^' . s:event
    let l:words = split(a:line)
    if get(l:words, 1, '') ==# 'stopped'
      let l:frames = s:frames
      let s:frames = []
      let l:id = get(l:words, 3, '-')
      let l:frame = str2nr(get(l:words, 2, '1'))
      " The request whose code is stopped answers only when it ends; the
      " ones made at the K>> prompt meanwhile must not wait behind it.
      if l:frame > 0 && s:current isnot v:null && s:current.id ==# l:id
        let s:current.suspended = 1
        let s:current = v:null
      endif
      " Frame 0: the session left the debugger by a route of its own.
      if l:frame > 0
        call matlabdebug#stopped(l:frames, l:frame, l:id)
      else
        call matlabdebug#resumed()
      endif
      call s:send_next()
    endif
    return
  endif
  if a:line =~# '^' . s:sentinel
    let l:words = split(a:line)
    let l:id = get(l:words, 1, '')
    let l:status = str2nr(get(l:words, 2, '1'))
    let s:receiving = ''
    if s:current isnot v:null && s:current.id ==# l:id
      let s:current = v:null
    endif
    if has_key(s:requests, l:id)
      let l:req = remove(s:requests, l:id)
      while !empty(l:req.lines) && empty(trim(l:req.lines[-1]))
        call remove(l:req.lines, -1)
      endwhile
      call s:complete(l:req, l:status, l:req.lines)
    endif
    call s:send_next()
  endif
endfunction

" Send {cmd} and wait for the reply. Synchronous on purpose: a reply takes
" a few milliseconds, and blocking keeps the caller simple. A stop in the
" debugger while waiting comes back as status 3 with the request's id, and
" the request stays open until the code runs to the end or is abandoned.
function! matlabserver#eval_sync(cmd, timeout_ms) abort
  let l:req = matlabserver#request('eval', a:cmd, v:null)
  let l:start = reltime()
  while !l:req.done && reltimefloat(reltime(l:start)) * 1000 < a:timeout_ms
    if l:req.suspended
      return {'ok': 0, 'status': 3, 'lines': ['stopped in the debugger'], 'id': l:req.id}
    endif
    sleep 10m
  endwhile
  if !l:req.done
    " The session carries on with what it was told to do, and its reply,
    " when it arrives, is matched by id and dropped.
    return {'ok': 0, 'status': -1, 'lines': ['timed out after '
      \ . a:timeout_ms . ' ms; the session is still running the command, and later'
      \ . ' requests wait behind it (:MatlabStop cuts it off)'], 'id': l:req.id}
  endif
  return {'ok': l:req.status == 0, 'status': l:req.status, 'lines': l:req.lines, 'id': l:req.id}
endfunction

" ------------------------------------------------------------- report

function! s:show(title, res) abort
  let l:win = 0
  for l:w in range(1, winnr('$'))
    if getbufvar(winbufnr(l:w), 'matlabserver_out', 0)
      let l:win = l:w
      break
    endif
  endfor
  if l:win
    execute l:win . 'wincmd w'
    keepalt keepjumps enew!
  else
    keepalt keepjumps new
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal modifiable noreadonly
  let b:matlabserver_out = 1
  let l:n = 0
  " :file expands wildcards, and an expression with a * in it made it
  " fail with "No match".
  let l:try = '[' . substitute(a:title, '[*?]', '_', 'g') . ']'
  while bufexists(l:try)
    let l:n += 1
    let l:try = '[' . a:title . ' ' . l:n . ']'
  endwhile
  execute 'silent keepalt file' fnameescape(l:try)
  let l:lines = empty(a:res.lines) ? ['(no output)'] : a:res.lines
  call setline(1, l:lines)
  setlocal nomodified nomodifiable
  setlocal filetype=matlabout
  normal! gg
endfunction

" Short and clean enough to just echo? Then do, and skip the window.
function! matlabserver#report(title, res) abort
  let l:body = filter(copy(a:res.lines), '!empty(trim(v:val))')
  if a:res.ok && len(l:body) <= 2
    redraw
    echo empty(l:body) ? 'matlabserver: ok' : join(l:body, '  ')
    return
  endif
  call s:show(a:title, a:res)
  if !a:res.ok
    call s:warn('the command raised; see the output window')
  endif
endfunction

function! matlabserver#eval(cmd) abort
  if empty(trim(a:cmd))
    call s:warn('nothing to evaluate')
    return
  endif
  let l:res = matlabserver#eval_sync(a:cmd, get(g:, 'matlabserver_timeout', 60000))
  if l:res.status == 3
    call matlabserver#on_done(l:res.id, {res -> matlabserver#report('Matlab ' . a:cmd, res)})
    return
  endif
  call matlabserver#report('Matlab ' . a:cmd, l:res)
endfunction

" The command that runs {file}: Matlab is moved to its directory first so
" that helpers sitting beside it resolve.
function! matlabserver#run_command(file) abort
  " A quote inside a Matlab string is doubled, not backslashed.
  return printf("cd('%s'); %s",
    \ substitute(fnamemodify(a:file, ':h'), "'", "''", 'g'), fnamemodify(a:file, ':t:r'))
endfunction

" Run the current file. Saved first.
function! matlabserver#run() abort
  if exists('*matlabdebug#status') && matlabdebug#status().active
    call matlabdebug#run('')
    return
  endif
  if &modified && !empty(bufname('%'))
    silent write
  endif
  let l:file = expand('%:p')
  if empty(l:file)
    call s:warn('this buffer has no file to run')
    return
  endif
  let l:name = fnamemodify(l:file, ':t:r')
  let l:res = matlabserver#eval_sync(matlabserver#run_command(l:file),
    \ get(g:, 'matlabserver_timeout', 60000))
  if l:res.status == 3
    call matlabserver#on_done(l:res.id, {res -> matlabserver#report('Matlab run ' . l:name, res)})
    return
  endif
  call matlabserver#report('Matlab run ' . l:name, l:res)
endfunction

" Leaving Vim would kill the session anyway; asking it to quit first lets
" Matlab shut down in its own time rather than being cut off mid-write.
augroup matlabserver_exit
  autocmd!
  autocmd VimLeavePre * if matlabserver#running() | call matlabserver#stop() | endif
augroup END

" Run the current file and put whatever it raised into the quickfix list, so
" :clist, :cnext and :cc walk it. This is what :make reaches in a Matlab
" buffer; see the abbreviation in plugin/matlabserver.vim.
"
" Written in Vimscript rather than behind 'makeprg'. :make would have to shell
" out to a program that can speak to the socket, and no such program ships
" with Vim, Windows or Matlab; the session is already a Vim channel, so
" :cgetexpr can read the reply straight and nothing else has to be installed.
"
" With a bang the cursor stays put, the way :make! differs from :make.
function! matlabserver#make(bang) abort
  " With the debugger open, :make is :Run: the breakpoints are sent again
  " first and the run is followed in the debugger's windows. Only the
  " report at the end differs from a plain :make, and it does not: :Run
  " ends in the same quickfix list.
  if exists('*matlabdebug#status') && matlabdebug#status().active
    call matlabdebug#run('')
    return
  endif
  " :make on a stale file is a trap, and Vim's own answer to it, 'autowrite',
  " is a global setting this should not turn on for you.
  if &modified && !empty(bufname('%'))
    silent update
  endif
  let l:file = expand('%:p')
  if empty(l:file)
    call s:warn('this buffer has no file to run')
    return
  endif
  if !matlabserver#ensure(get(g:, 'matlabserver_start_timeout', 30000))
    return
  endif
  let l:name = fnamemodify(l:file, ':t:r')
  redraw
  echo 'matlabserver: running ' . l:name . ' ...'
  let l:res = matlabserver#eval_sync(matlabserver#run_command(l:file),
    \ get(g:, 'matlabserver_timeout', 60000))
  if l:res.status == 3
    " A breakpoint. The debugger has the file now; the quickfix list gets
    " whatever the run raises once it ends.
    call matlabserver#on_done(l:res.id, {res -> matlabserver#finish_run(l:name, res, a:bang)})
    return
  endif
  call matlabserver#finish_run(l:name, l:res, a:bang)
endfunction

" Report the end of a run of {name}: output shown, errors into the quickfix
" list. Shared by :MatlabMake and the debugger's :Run.
function! matlabserver#finish_run(name, res, bang) abort
  redraw
  if a:res.status == 2
    echo 'matlabserver: ' . a:name . ' was abandoned'
    return
  endif
  if a:res.ok
    " Nothing raised, so there is nothing for the quickfix list; show whatever
    " the file printed instead.
    call setqflist([], 'r')
    call matlabserver#report('Matlab make ' . a:name, a:res)
    return
  endif
  " cgetexpr reads the current buffer's 'errorformat', which compiler/matlab.vim
  " set for matlab buffers, against the file:line: message lines the session
  " produces. Reached from a callback the current buffer may be another one,
  " so the format is named outright.
  let l:save = &errorformat
  if &filetype !=# 'matlab'
    let &errorformat = '%f:%l:%c: %m,%f:%l: %m,Error: %m,%-G%.%#'
  endif
  try
    cgetexpr a:res.lines
  finally
    let &errorformat = l:save
  endtry
  " Lines that matched no format are kept as invalid entries (:clist! shows
  " them); only the ones with a position count, and without any of those
  " the output window says more than an empty :clist would.
  let l:n = len(filter(getqflist(), 'v:val.valid'))
  if l:n == 0
    call matlabserver#report('Matlab make ' . a:name, a:res)
    return
  endif
  if !a:bang
    cfirst
  endif
  redraw
  echo printf('matlabserver: %s raised, %d quickfix entr%s (:clist)',
    \ a:name, l:n, l:n == 1 ? 'y' : 'ies')
endfunction
