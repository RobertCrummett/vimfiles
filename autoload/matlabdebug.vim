" A debugger for Matlab inside Vim, on top of the warm session that
" plugin/matlabserver.vim keeps: the line Matlab is stopped on is marked in
" the source, the stack and the variables of the selected frame sit in two
" windows of their own, and stepping is a command away. Modelled on Vim's
" own termdebug, down to the command names.
"
" The session does the stopping: a breakpoint set here is a real dbstop in
" the session, and :Step is a real dbstep. What this file adds is the
" bookkeeping around the stop events vimserver.m sends (see the protocol at
" the top of that file), the windows, and the signs. How the session manages
" to keep answering while stopped is a workaround on an undocumented
" interface, described at |matlabdebug-workaround|; nothing here depends on
" it directly, so when it is replaced only the session changes.

let s:active = 0            " windows open, commands defined
let s:stopped = 0           " Matlab is at a K>> prompt
let s:frames = []           " [{'line', 'name', 'file'}], innermost first
let s:frame = 1             " selected frame, 1 innermost
let s:run = ''              " id of the request whose code is running or stopped
let s:stops = 0             " stop events seen, so a caller can wait for the next
let s:runname = ''          " what :Run was given, for the report
let s:breaks = {}           " file key -> {line -> condition}, as Matlab has them
let s:asked = {}            " file key -> {line asked for -> line Matlab placed it on}
let s:files = {}            " file key -> the path as Vim spells it
let s:signs = {}            " file key -> {sign id -> condition}, so a sign that moved keeps its condition
let s:matlabroot = ''       " key of Matlab's own folder; files under it are not yours to edit
let s:watches = []          " expressions shown at every stop
let s:values = {}           " watch expression -> its last value
let s:vars = []             " variables of the selected frame, [name, size, class, value]
let s:srcwin = 0            " window id the source is shown in
let s:stackbuf = 0
let s:varsbuf = 0
let s:lastfile = ''         " what :Run ran last, for a bare :Run

function! s:width() abort
  return get(g:, 'matlabdebug_width', 45)
endfunction

function! s:msg(text) abort
  redraw
  echo 'matlabdebug: ' . a:text
endfunction

function! s:warn(text) abort
  redraw
  echohl WarningMsg | echomsg 'matlabdebug: ' . a:text | echohl NONE
endfunction

" One spelling of a path, for the breakpoint table and for matching what
" Matlab reports (backslashes, its own case) against what Vim has.
function! s:key(file) abort
  return tolower(substitute(fnamemodify(a:file, ':p'), '\\', '/', 'g'))
endfunction

" Matlab wants the path with its quotes doubled, on one line.
function! s:mpath(file) abort
  return substitute(fnamemodify(a:file, ':p'), '\\', '/', 'g')
endfunction

" ------------------------------------------------------------- signs

if !exists('s:signs_defined')
  let s:signs_defined = 1
  " Default highlights only; colors/custom.vim links both.
  highlight default debugPC term=reverse ctermbg=darkblue guibg=darkblue
  highlight default debugBreakpoint term=reverse ctermbg=red guibg=red
  " The highlighted line says where Matlab is; the margin stays clear
  " unless g:matlabdebug_pc_sign gives it something to show. A sign may
  " have no text at all, but not empty text (E239), hence the two dicts.
  let s:pc = {'texthl': 'debugPC', 'linehl': 'debugPC'}
  if !empty(get(g:, 'matlabdebug_pc_sign', ''))
    let s:pc.text = g:matlabdebug_pc_sign
  endif
  call sign_define('MatlabDebugPC', s:pc)
  call sign_define('MatlabDebugBreak', {'text': get(g:, 'matlabdebug_break_sign', '●'),
    \ 'texthl': 'debugBreakpoint'})
endif

function! s:place_pc(file, line) abort
  call sign_unplace('MatlabDebugPC')
  let l:buf = bufnr(a:file)
  if l:buf > 0 && a:line >= 1
    call sign_place(0, 'MatlabDebugPC', 'MatlabDebugPC', l:buf, {'lnum': a:line, 'priority': 30})
  endif
endfunction

" Redo the breakpoint signs of one file from the table.
function! s:place_breaks(file) abort
  let l:buf = bufnr(a:file)
  if l:buf <= 0
    return
  endif
  call sign_unplace('MatlabDebugBreak', {'buffer': l:buf})
  let l:key = s:key(a:file)
  let s:signs[l:key] = {}
  for [l:line, l:cond] in items(get(s:breaks, l:key, {}))
    let l:id = sign_place(0, 'MatlabDebugBreak', 'MatlabDebugBreak', l:buf, {'lnum': str2nr(l:line), 'priority': 20})
    let s:signs[l:key][l:id] = l:cond
  endfor
endfunction

" Signs move with the text when a buffer is edited; the table does not. So
" before the breakpoints are sent again, the table of every loaded file is
" rebuilt from where its signs are now.
function! s:breaks_from_signs() abort
  for l:key in keys(s:breaks)
    let l:buf = bufnr(get(s:files, l:key, l:key))
    if l:buf <= 0 || !bufloaded(l:buf)
      continue
    endif
    let l:table = {}
    for l:sign in sign_getplaced(l:buf, {'group': 'MatlabDebugBreak'})[0].signs
      let l:table[string(l:sign.lnum)] = get(get(s:signs, l:key, {}), l:sign.id, '')
    endfor
    if empty(l:table)
      unlet s:breaks[l:key]
    else
      let s:breaks[l:key] = l:table
    endif
  endfor
endfunction

" ------------------------------------------------------------ locking

" Matlab's own files are never yours to edit: one the debugger opens, by
" stepping into strsplit say, is made read-only for good. Your own files
" are left alone, stopped in or not; the signs follow an edit and the
" breakpoints are rebuilt from them at the next :Run.
function! s:lock(buf, file) abort
  if !empty(s:matlabroot) && s:key(a:file)[:len(s:matlabroot) - 1] ==# s:matlabroot
    call setbufvar(a:buf, '&modifiable', 0)
    call setbufvar(a:buf, '&readonly', 1)
  endif
endfunction

function! s:got_matlabroot(res) abort
  if a:res.ok && !empty(a:res.lines)
    " :p on an existing directory already ends it with a slash.
    let s:matlabroot = substitute(s:key(trim(a:res.lines[0])), '/*$', '/', '')
  endif
endfunction

" A file opened later gets the signs of the breakpoints it already has.
function! matlabdebug#buffer_loaded() abort
  let l:file = expand('<afile>:p')
  if !empty(l:file) && has_key(s:breaks, s:key(l:file))
    call s:place_breaks(l:file)
  endif
endfunction

" ----------------------------------------------------------- windows

function! s:is_ours(buf) abort
  return a:buf == s:stackbuf || a:buf == s:varsbuf || getbufvar(a:buf, 'matlabserver_out', 0)
endfunction

" The window the source goes in: the one it went in last time, else the
" current window unless that is one of ours, else the first that is not.
function! s:source_window() abort
  if s:srcwin && win_id2win(s:srcwin) && !s:is_ours(winbufnr(s:srcwin))
    return s:srcwin
  endif
  if !s:is_ours(bufnr('%'))
    let s:srcwin = win_getid()
    return s:srcwin
  endif
  for l:w in range(1, winnr('$'))
    if !s:is_ours(winbufnr(l:w))
      let s:srcwin = win_getid(l:w)
      return s:srcwin
    endif
  endfor
  " Only our windows exist: make one.
  wincmd t
  topleft new
  let s:srcwin = win_getid()
  return s:srcwin
endfunction

function! s:scratch(name) abort
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal nowrap nonumber norelativenumber nolist winfixwidth
  setlocal nomodifiable
  execute 'silent file' fnameescape(a:name)
  nnoremap <buffer> <silent> q <Cmd>MatlabDebugClose<CR>
endfunction

function! s:open_windows() abort
  let l:cur = win_getid()
  call s:source_window()
  execute 'botright' s:width() 'vnew'
  call s:scratch('[Matlab variables]')
  let s:varsbuf = bufnr('%')
  nnoremap <buffer> <silent> <CR> <Cmd>call <SID>vars_enter()<CR>
  nnoremap <buffer> <silent> dd <Cmd>call <SID>vars_delete()<CR>
  nnoremap <buffer> <silent> w <Cmd>call <SID>vars_toggle()<CR>
  belowright 10new
  call s:scratch('[Matlab stack]')
  let s:stackbuf = bufnr('%')
  nnoremap <buffer> <silent> <CR> <Cmd>call <SID>stack_enter()<CR>
  call win_gotoid(l:cur)
endfunction

function! s:close_windows() abort
  for l:buf in [s:stackbuf, s:varsbuf]
    if l:buf > 0 && bufexists(l:buf)
      for l:w in win_findbuf(l:buf)
        if winnr('$') > 1
          call win_execute(l:w, 'close')
        endif
      endfor
      execute 'silent! bwipeout!' l:buf
    endif
  endfor
  let s:stackbuf = 0
  let s:varsbuf = 0
endfunction

function! s:fill(buf, lines) abort
  if a:buf <= 0 || !bufexists(a:buf)
    return
  endif
  call setbufvar(a:buf, '&modifiable', 1)
  silent call deletebufline(a:buf, 1, '$')
  call setbufline(a:buf, 1, a:lines)
  call setbufvar(a:buf, '&modifiable', 0)
endfunction

function! s:refresh_stack() abort
  if !s:stopped
    call s:fill(s:stackbuf, ['(not stopped)'])
    return
  endif
  let l:lines = []
  for l:i in range(len(s:frames))
    let l:f = s:frames[l:i]
    call add(l:lines, printf('%s%d  %s  %s:%d', l:i + 1 == s:frame ? '>' : ' ',
      \ l:i + 1, l:f.name, fnamemodify(l:f.file, ':t'), l:f.line))
  endfor
  call s:fill(s:stackbuf, l:lines)
endfunction

function! s:refresh_vars() abort
  let l:lines = []
  if !empty(s:watches)
    call add(l:lines, 'Watch')
    for l:expr in s:watches
      call add(l:lines, printf('  %s = %s', l:expr, get(s:values, l:expr, '?')))
    endfor
    call add(l:lines, '')
  endif
  if s:stopped && s:frame <= len(s:frames)
    let l:f = s:frames[s:frame - 1]
    call add(l:lines, printf('Variables  %s (line %d)', l:f.name, l:f.line))
  else
    call add(l:lines, 'Variables  (base)')
  endif
  let l:w = max([4] + map(copy(s:vars), 'strdisplaywidth(v:val[0])'))
  for l:v in s:vars
    " A * marks a variable that is also watched.
    call add(l:lines, printf('%s %-' . l:w . 's  %-7s %-8s %s',
      \ index(s:watches, l:v[0]) >= 0 ? '*' : ' ', l:v[0], l:v[1], l:v[2], l:v[3]))
  endfor
  call s:fill(s:varsbuf, l:lines)
endfunction

" Which part of the variables window the cursor line is in, and what it
" names: ['watch', expr], ['var', name] or ['', ''].
function! s:vars_at_cursor() abort
  let l:line = getline('.')
  let l:section = ''
  for l:n in range(line('.'), 1, -1)
    if getline(l:n) =~# '^Variables'
      let l:section = 'var'
      break
    elseif getline(l:n) =~# '^Watch'
      let l:section = 'watch'
      break
    endif
  endfor
  if l:section ==# 'watch' && l:line =~# '^  \S.* = '
    return ['watch', matchstr(l:line, '^  \zs.\{-}\ze = ')]
  elseif l:section ==# 'var' && l:line =~# '^[* ] \S'
    return ['var', matchstr(l:line, '^[* ] \zs\S\+')]
  endif
  return ['', '']
endfunction

" What the variables window shows is fetched fresh: the variables of the
" selected frame, and every watch expression.
function! s:fetch() abort
  call matlabserver#request('vars', '', function('s:got_vars'))
  for l:expr in s:watches
    call matlabserver#request('eval', s:watch_command(l:expr), function('s:got_watch', [l:expr]))
  endfor
endfunction

function! s:got_vars(res) abort
  let s:vars = []
  if a:res.ok
    for l:line in a:res.lines
      let l:parts = split(l:line, "\t", 1)
      if len(l:parts) >= 3
        call add(s:vars, [l:parts[0], l:parts[1], l:parts[2], join(l:parts[3:], "\t")])
      endif
    endfor
  endif
  call s:refresh_vars()
endfunction

" disp() of the expression, so nothing is assigned in the frame; a value
" of several lines is shown on one.
function! s:watch_command(expr) abort
  return printf('disp(%s)', a:expr)
endfunction

function! s:got_watch(expr, res) abort
  let l:lines = filter(copy(a:res.lines), '!empty(trim(v:val))')
  let s:values[a:expr] = join(map(l:lines, 'trim(v:val)'), ' ')
  call s:refresh_vars()
endfunction

function! s:stack_enter() abort
  let l:n = str2nr(matchstr(getline('.'), '^.\zs\d\+'))
  if l:n > 0
    call matlabdebug#frame(l:n)
  endif
endfunction

function! s:vars_enter() abort
  let [l:what, l:name] = s:vars_at_cursor()
  if !empty(l:what)
    call matlabdebug#evaluate(l:name)
  endif
endfunction

function! s:vars_delete() abort
  let [l:what, l:name] = s:vars_at_cursor()
  if l:what ==# 'watch'
    call matlabdebug#unwatch(l:name)
  endif
endfunction

" w in the variables window: watch the variable on this line, or stop.
function! s:vars_toggle() abort
  let [l:what, l:name] = s:vars_at_cursor()
  if !empty(l:what)
    call matlabdebug#watch_toggle(l:name)
  endif
endfunction

" ---------------------------------------------------------- commands

function! s:define_commands() abort
  command! -nargs=? -complete=file Run       call matlabdebug#run(<q-args>)
  command! -nargs=* Break                    call matlabdebug#break(<q-args>)
  command! -nargs=? Clear                    call matlabdebug#clear(<q-args>)
  command! -bar Step                         call matlabdebug#dbg('dbstep in')
  command! -bar Over                         call matlabdebug#dbg('dbstep')
  command! -bar Finish                       call matlabdebug#dbg('dbstep out')
  command! -bar Continue                     call matlabdebug#dbg('dbcont')
  command! -bar Stop                         call matlabdebug#dbg('dbquit')
  command! -bar Up                           call matlabdebug#dbg('dbup')
  command! -bar Down                         call matlabdebug#dbg('dbdown')
  command! -bar -nargs=1 Frame               call matlabdebug#frame(str2nr(<q-args>))
  command! -nargs=* -range=0 Evaluate        call matlabdebug#evaluate_cmd(<q-args>, <count>)
  command! -nargs=* Watch                    call matlabdebug#watch_cmd(<q-args>)
  command! -nargs=+ Unwatch                  call matlabdebug#unwatch(<q-args>)
endfunction

function! s:delete_commands() abort
  for l:c in ['Run', 'Break', 'Clear', 'Step', 'Over', 'Finish', 'Continue',
    \ 'Stop', 'Up', 'Down', 'Frame', 'Evaluate', 'Watch', 'Unwatch']
    if exists(':' . l:c) == 2
      execute 'delcommand' l:c
    endif
  endfor
endfunction

" :MatlabDebug opens the windows and defines the commands. It does not run
" anything: set breakpoints with :Break, then :Run.
function! matlabdebug#open() abort
  if s:active
    call s:msg('already open')
    return
  endif
  let s:active = 1
  call s:open_windows()
  call s:define_commands()
  call s:refresh_stack()
  call s:refresh_vars()
  if !matlabserver#running()
    call matlabserver#start()
  endif
  if empty(s:matlabroot)
    call matlabserver#request('eval', 'disp(matlabroot)', function('s:got_matlabroot'))
  endif
endfunction

" :MatlabDebugClose. A stopped run is abandoned, and every breakpoint goes:
" the signs, the table, and the session's own, so that the next :make runs
" the file through without a stop that would open the debugger again.
function! matlabdebug#close() abort
  if !s:active
    return
  endif
  if s:stopped
    call matlabserver#request('dbg', 'dbquit', v:null)
  endif
  call matlabdebug#clear_all()
  call matlabdebug#reset()
endfunction

" Forget every breakpoint, here and in the session.
function! matlabdebug#clear_all() abort
  if matlabserver#running()
    call matlabserver#request('clear', '', v:null)
  endif
  call sign_unplace('MatlabDebugBreak')
  let s:breaks = {}
  let s:asked = {}
  let s:signs = {}
  let s:files = {}
endfunction

" Everything back to not-debugging: windows, commands, the PC sign. Also
" what the session's exit calls.
function! matlabdebug#reset() abort
  call sign_unplace('MatlabDebugPC')
  let s:stopped = 0
  let s:frames = []
  let s:frame = 1
  let s:run = ''
  let s:vars = []
  if s:active
    call s:close_windows()
    call s:delete_commands()
    let s:active = 0
  endif
endfunction

" :Run [file]. The file, or the current buffer, or what ran last. The
" breakpoints are sent again first, cleared and set, so that a session
" started since :Break has them too.
function! matlabdebug#run(file) abort
  if s:stopped
    call s:warn('stopped in the debugger; :Continue or :Stop first')
    return
  endif
  if !empty(s:run)
    call s:warn('a run is in progress')
    return
  endif
  let l:file = a:file
  if empty(l:file)
    let l:file = &filetype ==# 'matlab' ? expand('%:p') : s:lastfile
  endif
  if empty(l:file)
    call s:warn('nothing to run: give a file, or run from a matlab buffer')
    return
  endif
  let l:file = fnamemodify(l:file, ':p')
  let l:buf = bufnr(l:file)
  if l:buf > 0 && getbufvar(l:buf, '&modified')
    if bufwinid(l:buf) < 0
      call s:warn(fnamemodify(l:file, ':t') . ' has unsaved changes in a hidden buffer; write it first')
      return
    endif
    call win_execute(bufwinid(l:buf), 'silent update')
  endif
  if !matlabserver#ensure(get(g:, 'matlabserver_start_timeout', 30000))
    return
  endif
  let s:lastfile = l:file
  let s:runname = fnamemodify(l:file, ':t:r')
  call s:breaks_from_signs()
  call matlabserver#request('clear', '', v:null)
  for l:key in keys(s:breaks)
    for [l:line, l:cond] in items(s:breaks[l:key])
      call matlabserver#request('break', l:key . "\t" . l:line . "\t" . l:cond,
        \ function('s:breaks_done', [get(s:files, l:key, l:key), 0]))
    endfor
  endfor
  let l:req = matlabserver#request('eval', matlabserver#run_command(l:file), function('s:run_done'))
  " A request that failed on the spot (connection gone) has called
  " s:run_done already; it must not be remembered as in progress.
  if !l:req.done
    let s:run = l:req.id
    call s:msg('running ' . s:runname . ' ...')
  endif
endfunction

" Our own :Run ended: back to not stopped, and report it.
function! s:run_done(res) abort
  call s:run_ended(a:res)
  call matlabserver#finish_run(s:runname, a:res, 1)
endfunction

" A run started elsewhere (:make, :Matlab) ended: whoever started it
" reports; here only the state changes.
function! s:run_ended(res) abort
  if !empty(s:run) && a:res.id !=# s:run
    return
  endif
  call sign_unplace('MatlabDebugPC')
  let s:stopped = 0
  let s:frames = []
  let s:frame = 1
  let s:run = ''
  call s:refresh_stack()
  let s:vars = []
  call s:refresh_vars()
endfunction

" The session left the debugger without being asked by a command of ours.
function! matlabdebug#resumed() abort
  if !s:stopped
    return
  endif
  call s:run_ended({'id': s:run})
  call s:msg('no longer stopped')
endfunction

" A stop, reported by the session: {frames} innermost first, {frame} the
" selected one, {id} the request whose code is stopped. Reached from
" :Run, but also from :make or :Matlab on a file with a breakpoint in it,
" in which case the windows open now.
function! matlabdebug#stopped(frames, frame, id) abort
  let s:frames = a:frames
  let s:frame = max([1, min([a:frame, len(a:frames)])])
  let s:stopped = 1
  let s:stops += 1
  if !s:active
    call matlabdebug#open()
  endif
  if a:id !=# '-' && a:id !=# s:run
    " Not our :Run (:make, :Matlab): whoever started it reports its end;
    " the windows still have to follow.
    let s:run = a:id
    let s:runname = 'the run'
    call matlabserver#on_done(a:id, function('s:run_ended'))
  endif
  if empty(s:frames)
    call s:msg('stopped, but nowhere Vim can show')
    call s:refresh_stack()
    call s:fetch()
    return
  endif
  call s:show_frame()
  call s:refresh_stack()
  call s:fetch()
  let l:f = s:frames[s:frame - 1]
  call s:msg(printf('stopped in %s at line %d', l:f.name, l:f.line))
endfunction

" Put the selected frame's line on screen and mark it.
function! s:show_frame() abort
  let l:f = s:frames[s:frame - 1]
  if !filereadable(l:f.file)
    return
  endif
  let l:cur = win_getid()
  call win_gotoid(s:source_window())
  let l:buf = bufadd(l:f.file)
  call bufload(l:buf)
  if bufnr('%') != l:buf
    " :hide so that a modified buffer does not stop the switch.
    execute 'silent keepalt hide buffer' l:buf
    setlocal buflisted
  endif
  if l:f.line >= 1
    execute 'normal!' l:f.line . 'Gzv'
  endif
  call s:place_pc(l:f.file, l:f.line)
  call s:place_breaks(l:f.file)
  call s:lock(l:buf, l:f.file)
  if l:cur != win_getid() && s:is_ours(winbufnr(l:cur))
    call win_gotoid(l:cur)
  endif
endfunction

function! matlabdebug#dbg(cmd) abort
  if !s:stopped
    call s:warn('not stopped in the debugger')
    return
  endif
  call matlabserver#request('dbg', a:cmd, function('s:dbg_done', [a:cmd]))
endfunction

function! s:dbg_done(cmd, res) abort
  if !a:res.ok
    call s:warn(join(a:res.lines, ' '))
  endif
endfunction

" :Frame {n}: select by number, through as many dbup or dbdown as it takes.
" Each one comes back as a stop event that redraws.
function! matlabdebug#frame(n) abort
  if !s:stopped
    call s:warn('not stopped in the debugger')
    return
  endif
  if a:n < 1 || a:n > len(s:frames)
    call s:warn('no frame ' . a:n)
    return
  endif
  let l:cmd = a:n > s:frame ? 'dbup' : 'dbdown'
  for l:i in range(abs(a:n - s:frame))
    call matlabserver#request('dbg', l:cmd, v:null)
  endfor
endfunction

" :Break [line] [if condition]: toggle a breakpoint on the cursor line of
" the current buffer, or on {line}. Matlab may move it to the next line
" that runs; the sign goes where Matlab put it.
function! matlabdebug#break(args) abort
  if &filetype !=# 'matlab' || empty(expand('%:p'))
    call s:warn('breakpoints go in a matlab buffer')
    return
  endif
  let l:file = expand('%:p')
  let l:line = line('.')
  let l:cond = ''
  let l:m = matchlist(a:args, '^\s*\(\d*\)\s*\%(if\s\+\(.*\)\)\?$')
  if !empty(l:m)
    if !empty(l:m[1])
      let l:line = str2nr(l:m[1])
    endif
    let l:cond = trim(l:m[2])
  endif
  let l:key = s:key(l:file)
  let l:placed = s:placed(l:key, l:line)
  if l:placed > 0 && empty(l:cond)
    call matlabdebug#clear(string(l:placed))
    return
  endif
  if !matlabserver#ensure(get(g:, 'matlabserver_start_timeout', 30000))
    return
  endif
  call matlabserver#request('break', s:mpath(l:file) . "\t" . l:line . "\t" . l:cond,
    \ function('s:breaks_done', [l:file, l:line]))
endfunction

" The line a breakpoint sits on, given the line it was asked for: the
" same line if there is one there, else the line Matlab moved it to when
" that was asked for (a comment moves to the next line that runs). 0 if
" neither.
function! s:placed(key, line) abort
  if has_key(get(s:breaks, a:key, {}), string(a:line))
    return a:line
  endif
  let l:moved = get(get(s:asked, a:key, {}), string(a:line), 0)
  if l:moved && has_key(get(s:breaks, a:key, {}), string(l:moved))
    return l:moved
  endif
  return 0
endfunction

" :Clear [line]: remove the breakpoint on the cursor line, or on {line}.
function! matlabdebug#clear(args) abort
  if &filetype !=# 'matlab' || empty(expand('%:p'))
    call s:warn('breakpoints go in a matlab buffer')
    return
  endif
  let l:file = expand('%:p')
  let l:line = empty(trim(a:args)) ? line('.') : str2nr(a:args)
  let l:line = s:placed(s:key(l:file), l:line)
  if l:line == 0
    call s:warn('no breakpoint on line ' . (empty(trim(a:args)) ? line('.') : a:args))
    return
  endif
  if !matlabserver#ensure(get(g:, 'matlabserver_start_timeout', 30000))
    return
  endif
  call matlabserver#request('clear', s:mpath(l:file) . "\t" . l:line,
    \ function('s:breaks_done', [l:file, 0]))
endfunction

" The session's list of the file's breakpoints, after a change. {asked}
" is the line a :Break asked for, or 0 for a :Clear.
function! s:breaks_done(file, asked, res) abort
  if !a:res.ok
    call s:warn(join(a:res.lines, ' '))
    return
  endif
  let l:table = {}
  for l:line in a:res.lines
    let l:parts = split(l:line, "\t", 1)
    if !empty(l:parts) && str2nr(l:parts[0]) > 0
      let l:table[string(str2nr(l:parts[0]))] = get(l:parts, 1, '')
    endif
  endfor
  let l:key = s:key(a:file)
  let s:files[l:key] = fnamemodify(a:file, ':p')
  let l:before = get(s:breaks, l:key, {})
  if empty(l:table)
    if has_key(s:breaks, l:key)
      unlet s:breaks[l:key]
    endif
  else
    let s:breaks[l:key] = l:table
  endif
  " Where did the one just asked for land? On a new line of the table, or
  " on the line itself.
  if a:asked > 0
    let l:new = filter(keys(l:table), '!has_key(l:before, v:val)')
    if !has_key(s:asked, l:key)
      let s:asked[l:key] = {}
    endif
    let s:asked[l:key][string(a:asked)] = len(l:new) == 1 ? str2nr(l:new[0]) : a:asked
  endif
  call s:place_breaks(a:file)
  let l:n = len(l:table)
  call s:msg(printf('%d breakpoint%s in %s', l:n, l:n == 1 ? '' : 's', fnamemodify(a:file, ':t')))
endfunction

" :Evaluate [expr], or :'<,'>Evaluate for the selection; bare, the word
" under the cursor. In the selected frame while stopped, else in base.
function! matlabdebug#evaluate_cmd(args, count) abort
  let l:expr = a:args
  if empty(l:expr)
    if a:count > 0
      let l:save = @"
      silent normal! gvy
      let l:expr = substitute(@", '\n', ' ', 'g')
      let @" = l:save
    else
      let l:expr = expand('<cword>')
    endif
  endif
  if empty(trim(l:expr))
    call s:warn('nothing to evaluate')
    return
  endif
  call matlabdebug#evaluate(l:expr)
endfunction

function! matlabdebug#evaluate(expr) abort
  call matlabserver#request('eval', a:expr, {res -> matlabserver#report('Matlab ' . a:expr, res)})
endfunction

" :Watch {expr} watches; a bare :Watch toggles the word under the cursor,
" or, in the variables window, what the cursor line names.
function! matlabdebug#watch_cmd(args) abort
  if !empty(trim(a:args))
    call matlabdebug#watch(a:args)
    return
  endif
  if bufnr('%') == s:varsbuf
    call s:vars_toggle()
    return
  endif
  let l:word = expand('<cword>')
  if empty(l:word)
    call s:warn('nothing under the cursor to watch')
    return
  endif
  call matlabdebug#watch_toggle(l:word)
endfunction

function! matlabdebug#watch_toggle(expr) abort
  if index(s:watches, trim(a:expr)) >= 0
    call matlabdebug#unwatch(a:expr)
  else
    call matlabdebug#watch(a:expr)
  endif
endfunction

function! matlabdebug#watch(expr) abort
  let l:expr = trim(a:expr)
  if index(s:watches, l:expr) < 0
    call add(s:watches, l:expr)
  endif
  if s:active
    call s:refresh_vars()
    call matlabserver#request('eval', s:watch_command(l:expr), function('s:got_watch', [l:expr]))
  endif
endfunction

function! matlabdebug#unwatch(expr) abort
  let l:expr = trim(a:expr)
  let l:i = index(s:watches, l:expr)
  if l:i < 0 && l:expr =~# '^\d\+$' && str2nr(l:expr) <= len(s:watches)
    let l:i = str2nr(l:expr) - 1
  endif
  if l:i < 0
    call s:warn('not watching ' . l:expr)
    return
  endif
  call remove(s:watches, l:i)
  call s:refresh_vars()
endfunction

" Where things stand, for a statusline or a test: whether the debugger is
" open, whether Matlab is stopped, the frames and the selected one, the
" breakpoint table and the watches.
function! matlabdebug#status() abort
  return {'active': s:active, 'stopped': s:stopped, 'frames': deepcopy(s:frames),
    \ 'frame': s:frame, 'run': s:run, 'stops': s:stops, 'breaks': deepcopy(s:breaks),
    \ 'watches': copy(s:watches), 'values': copy(s:values), 'vars': deepcopy(s:vars)}
endfunction
