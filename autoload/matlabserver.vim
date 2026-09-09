" One Matlab session, kept alive and spoken to over a loopback socket, so
" running something costs milliseconds instead of the five seconds Matlab
" needs to start. matlabserver/server.m is the other half.
"
" This session is its own process with its own workspace. It does not share
" anything with a Matlab desktop you have open, which is the point: the
" desktop stays free for the debugger while this one answers Vim.

" vimfiles itself. Resolved here and not inside a function: <sfile> names the
" sourced script only at script level, and the running function inside one.
let s:root = expand('<sfile>:p:h:h')

let s:sentinel = '--MATLABSERVER-DONE--'
let s:job = v:null          " the matlab process running server.m
let s:ch = v:null           " the channel to it
let s:reply = []            " lines collected for the command in flight
let s:pending = {}          " what that command was

function! s:dir() abort
  return s:root . '/matlabserver'
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
  let s:ch = ch_open('127.0.0.1:' . s:port(),
    \ {'mode': 'nl', 'waittime': 200, 'drop': 'never'})
  return ch_status(s:ch) ==# 'open'
endfunction

function! s:started(job, status) abort
  let s:job = v:null
  let s:ch = v:null
  echomsg 'matlabserver: the Matlab session exited (status ' . a:status . ')'
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
  let s:job = job_start([l:exe, '-sd', s:dir(), '-batch',
    \ printf('server(%d, %d)', s:port(), s:idle())],
    \ {'in_io': 'null', 'out_io': 'file', 'out_name': s:dir() . '/server.log',
    \  'err_io': 'out', 'exit_cb': function('s:started')})
  if job_status(s:job) !=# 'run'
    let s:job = v:null
    call s:err('could not run ' . l:exe)
    return
  endif
  echo printf('matlabserver: starting Matlab, ready in a few seconds '
    \ . '(:MatlabStatus to check; it closes itself after %d min idle)',
    \ s:idle() / 60)
endfunction

function! matlabserver#stop() abort
  if s:ch isnot v:null && ch_status(s:ch) ==# 'open'
    call ch_sendraw(s:ch, "quit\n")
    call ch_close(s:ch)
  endif
  let s:ch = v:null
  if matlabserver#running()
    call job_stop(s:job)
  endif
  let s:job = v:null
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
  if !s:connect()
    return {'ok': 0, 'status': -1, 'lines': ['could not connect on port ' . s:port()
      \ . '; Matlab may still be starting']}
  endif
  call ch_sendraw(s:ch, a:cmd . "\n")
  let l:lines = []
  let l:deadline = reltime()
  while reltimefloat(reltime(l:deadline)) * 1000 < a:timeout_ms
    let l:line = ch_read(s:ch, {'timeout': 200})
    if empty(l:line) && ch_status(s:ch) !=# 'open'
      return {'ok': 0, 'status': -1, 'lines': l:lines + ['connection closed']}
    endif
    if l:line =~# '^' . s:sentinel
      let l:status = str2nr(matchstr(l:line, '\d\+$'))
      while !empty(l:lines) && empty(trim(l:lines[-1]))
        call remove(l:lines, -1)
      endwhile
      return {'ok': l:status == 0, 'status': l:status, 'lines': l:lines}
    endif
    if !empty(l:line) || ch_status(s:ch) ==# 'open'
      call add(l:lines, l:line)
    endif
  endwhile
  return {'ok': 0, 'status': -1, 'lines': l:lines + ['timed out after '
    \ . a:timeout_ms . ' ms']}
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
  setlocal filetype=matlabserver
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
  let l:cmd = printf("cd('%s'); %s", escape(l:dir, "'"), l:name)
  call s:report('Matlab run ' . l:name,
    \ matlabserver#eval_sync(l:cmd, get(g:, 'matlabserver_timeout', 60000)))
endfunction

" Leaving Vim would kill the session anyway; asking it to quit first lets
" Matlab shut down in its own time rather than being cut off mid-write.
augroup matlabserver_exit
  autocmd!
  autocmd VimLeavePre * if matlabserver#running() | call matlabserver#stop() | endif
augroup END
