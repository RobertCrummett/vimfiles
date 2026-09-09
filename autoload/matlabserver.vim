" One Matlab session, kept alive and spoken to over a loopback socket, so
" running something costs milliseconds instead of the five seconds Matlab
" needs to start. matlab/server.m is the other half.
"
" This session is its own process with its own workspace. It does not share
" anything with a Matlab desktop you have open, which is the point: the
" desktop stays free for the debugger while this one answers Vim.

" vimfiles itself. Resolved here and not inside a function: <sfile> names the
" sourced script only at script level, and the running function inside one.
let s:root = expand('<sfile>:p:h:h')

let s:sentinel = '--MATLABSERVER-DONE--'
" The command sent to see whether the session answers. Not "1": that is an
" expression, and every ping would set ans in the user's workspace.
let s:ping = "disp('')"
let s:job = v:null          " the matlab process running server.m
let s:ch = v:null           " the channel to it
let s:reply = []            " lines collected for the command in flight
let s:pending = {}          " what that command was

function! s:dir() abort
  return s:root . '/matlab'
endfunction

function! s:port() abort
  return get(g:, 'matlabserver_port', 51763)
endfunction

" Seconds of quiet before the session shuts itself down. Enforced inside
" server.m, so it holds even if Vim never gets to run its VimLeavePre.
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
  " Raw rather than nl mode: ch_read() in nl mode returns an empty string
  " both for an empty line and for a timeout, so every 200 ms of a slow
  " command showed up as a blank line at the top of its output. In raw mode
  " an empty read means only that nothing has arrived; lines are split here.
  let s:ch = ch_open('127.0.0.1:' . s:port(),
    \ {'mode': 'raw', 'waittime': 200, 'drop': 'never'})
  return ch_status(s:ch) ==# 'open'
endfunction

function! s:disconnect() abort
  if s:ch isnot v:null
    silent! call ch_close(s:ch)
  endif
  let s:ch = v:null
endfunction

function! s:exited(job, status) abort
  " After :MatlabStop the job is already forgotten and the exit is expected;
  " only an exit nobody asked for is worth a message. Status 0 out of the
  " blue is the idle timeout in server.m.
  if a:job isnot s:job
    return
  endif
  let s:job = v:null
  call s:disconnect()
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
  " Under the watchdog so that a Vim that is killed rather than quit takes
  " the session with it; a normal exit does that by itself, a killed one
  " left MATLAB.exe running until the idle timeout. See autoload/watchdog.vim.
  let s:job = job_start(watchdog#wrap([l:exe, '-sd', s:dir(), '-batch',
    \ printf('server(%d, %d)', s:port(), s:idle())]),
    \ {'in_io': 'null', 'out_io': 'file', 'out_name': s:dir() . '/server.log',
    \  'err_io': 'out', 'exit_cb': function('s:exited')})
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
    " Until server.m is listening the connect fails at once, so pace the
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
    call ch_sendraw(s:ch, "quit\n")
    let l:asked = 1
  endif
  call s:disconnect()
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

" -------------------------------------------------------------- eval

" Send {cmd} and wait for the sentinel. Synchronous on purpose: a reply takes
" a few milliseconds, and blocking keeps the caller simple.
function! matlabserver#eval_sync(cmd, timeout_ms) abort
  if !matlabserver#running()
    return {'ok': 0, 'status': -1, 'lines': ['matlabserver is not running; :MatlabStart']}
  endif
  " The protocol is one command per line. A newline inside the command would
  " be read as a second command, and every reply after that would answer the
  " wrong question.
  if a:cmd =~# "[\n\r]"
    return {'ok': 0, 'status': -1, 'lines': ['a command must be a single line']}
  endif
  if !s:connect()
    return {'ok': 0, 'status': -1, 'lines': ['could not connect on port ' . s:port()
      \ . '; Matlab may still be starting']}
  endif
  " Anything still unread is the tail of a reply that was given up on; drop
  " it so it is not taken for this command's answer.
  while !empty(ch_readraw(s:ch, {'timeout': 0}))
  endwhile
  call ch_sendraw(s:ch, a:cmd . "\n")
  let l:buf = ''
  let l:lines = []
  let l:start = reltime()
  while reltimefloat(reltime(l:start)) * 1000 < a:timeout_ms
    let l:chunk = ch_readraw(s:ch, {'timeout': 100})
    if empty(l:chunk)
      if ch_status(s:ch) !=# 'open'
        call s:disconnect()
        return {'ok': 0, 'status': -1, 'lines': l:lines + ['connection closed']}
      endif
      continue
    endif
    let l:buf .= l:chunk
    let l:nl = strridx(l:buf, "\n")
    if l:nl < 0
      continue
    endif
    for l:line in split(strpart(l:buf, 0, l:nl), "\n", 1)
      if l:line =~# '^' . s:sentinel
        let l:status = str2nr(matchstr(l:line, '\d\+$'))
        while !empty(l:lines) && empty(trim(l:lines[-1]))
          call remove(l:lines, -1)
        endwhile
        return {'ok': l:status == 0, 'status': l:status, 'lines': l:lines}
      endif
      call add(l:lines, l:line)
    endfor
    let l:buf = strpart(l:buf, l:nl + 1)
  endwhile
  " The reply, when it does arrive, would be mistaken for the next command's.
  " Dropping the connection makes the session discard it: writes to a closed
  " socket go nowhere, and the next command opens a fresh one.
  call s:disconnect()
  return {'ok': 0, 'status': -1, 'lines': l:lines + ['timed out after '
    \ . a:timeout_ms . ' ms; the session is still running the command']}
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
  let l:try = '[' . a:title . ']'
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
function! s:report(title, res) abort
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
  call s:report('Matlab ' . a:cmd,
    \ matlabserver#eval_sync(a:cmd, get(g:, 'matlabserver_timeout', 60000)))
endfunction

" Run the current file. Saved first, and Matlab is moved to its directory so
" that helpers sitting beside it resolve.
function! matlabserver#run() abort
  if &modified && !empty(bufname('%'))
    silent write
  endif
  let l:file = expand('%:p')
  if empty(l:file)
    call s:warn('this buffer has no file to run')
    return
  endif
  let l:dir = fnamemodify(l:file, ':h')
  let l:name = fnamemodify(l:file, ':t:r')
  " A quote inside a Matlab string is doubled, not backslashed.
  let l:cmd = printf("cd('%s'); %s", substitute(l:dir, "'", "''", 'g'), l:name)
  call s:report('Matlab run ' . l:name,
    \ matlabserver#eval_sync(l:cmd, get(g:, 'matlabserver_timeout', 60000)))
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
" It is also faster, and it avoids the deadlock a second client caused: the
" session serves one at a time, and Vim holding the socket starved it.
"
" With a bang the cursor stays put, the way :make! differs from :make.
function! matlabserver#make(bang) abort
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
  let l:res = matlabserver#eval_sync(
    \ printf("cd('%s'); %s", substitute(fnamemodify(l:file, ':h'), "'", "''", 'g'), l:name),
    \ get(g:, 'matlabserver_timeout', 60000))

  redraw
  if l:res.ok
    " Nothing raised, so there is nothing for the quickfix list; show whatever
    " the file printed instead.
    call setqflist([], 'r')
    call s:report('Matlab make ' . l:name, l:res)
    return
  endif
  " cgetexpr reads this buffer's 'errorformat', which compiler/matlab.vim set,
  " against the file:line: message lines server.m produces.
  cgetexpr l:res.lines
  " Lines that matched no format are kept as invalid entries (:clist! shows
  " them); only the ones with a position count, and without any of those
  " the output window says more than an empty :clist would.
  let l:n = len(filter(getqflist(), 'v:val.valid'))
  if l:n == 0
    call s:report('Matlab make ' . l:name, l:res)
    return
  endif
  if !a:bang
    cfirst
  endif
  redraw
  echo printf('matlabserver: %s raised, %d quickfix entr%s (:clist)',
    \ l:name, l:n, l:n == 1 ? 'y' : 'ies')
endfunction

