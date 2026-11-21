" The build behind plugin/bgmake.vim.
"
" A :make during a build does not stop it. Killing a build can leave a
" half-written PDF, .aux or object file behind, so the :make asked for
" during it follows it instead, in its own buffer and directory.

let s:build = {}      " the running build, or empty
let s:next = {}       " the last :make asked for during it, or empty
let s:cmdline = ''    " the command line last typed, until a :make takes it

" 'statusline' can show this.
function! bgmake#running() abort
  return !empty(s:build)
endfunction

function! bgmake#wanted() abort
  return index(g:bgmake_filetypes, '*') >= 0 || index(g:bgmake_filetypes, &filetype) >= 0
endfunction

" CmdlineLeave on a : line. What was typed, for bgmake#args(), unless it was
" abandoned: v:char is the key that left the line, and some Vims also say so
" in v:event.
function! bgmake#typed() abort
  let l:abandoned = get(v:event, 'abort', 0) || v:char ==# "\<Esc>" || v:char ==# "\<C-C>"
  let s:cmdline = l:abandoned ? '' : getcmdline()
endfunction

" The arguments of the :make that is starting, from the command line typed
" for it: after modifiers such as :silent, "make", and a !, up to a bar that
" is not escaped, as for :make itself. A :make from a script or a <Cmd>
" mapping leaves no command line, and has none. The line is taken once, so
" that one typed earlier is never used for a later :make.
function! bgmake#args() abort
  let l:line = s:cmdline
  let s:cmdline = ''
  let l:m = matchlist(l:line, '^[: \t]*\%(\h\w*!\=\s\+\)*mak\%[e]!\=\%(\s\+\(\%([^|\\]\|\\.\)*\)\)\=\s*\%(|\|$\)')
  return empty(l:m) ? '' : substitute(trim(l:m[1]), '\\|', '|', 'g')
endfunction

" The command :make would run: the arguments in place of every $* in
" 'makeprg', or after it, and then % and the like expanded.
function! s:command(args) abort
  let l:prg = &makeprg
  if l:prg =~# '\$\*'
    let l:prg = substitute(l:prg, '\$\*', escape(a:args, '\&'), 'g')
  elseif !empty(a:args)
    let l:prg .= ' ' . a:args
  endif
  return expandcmd(l:prg)
endfunction

function! bgmake#make(args, timer) abort
  " :make on a stale file is a trap, as in matlabserver#make(). Only a buffer
  " that is a file is written: writing a listing or a terminal means
  " something else, or nothing, and a buffer with no name still builds.
  try
    if &modified && &buftype ==# '' && !empty(bufname('%'))
      silent update
    endif
    let l:request = {'cmd': s:command(a:args), 'efm': &errorformat, 'dir': getcwd(),
      \ 'buffer': bufnr('%')}
  catch
    " E499 for a % in 'makeprg' in a buffer with no name, or a write that failed.
    call s:warn(substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', ''))
    return
  endtry
  if !empty(s:build)
    let s:next = l:request
    echo 'make: one more build after this one'
    return
  endif
  call s:start(l:request)
  if !empty(s:build)
    echo 'make: building'
  endif
endfunction

function! s:warn(message) abort
  echohl ErrorMsg | echomsg 'bgmake: ' . a:message | echohl None
endfunction

" What the shell is given to run a:cmd. With cmd.exe ('shellxquote' is ( or
" "() it is the line :make builds, ( and ) around the command and nothing
" escaped: given a list instead, Vim quotes each argument for C programs, and
" Lean was handed "t.lean", quotes and all. Any other shell takes the command
" as one argument, as before; 'shell' may carry its own quotes.
function! s:shell(cmd) abort
  let l:cmd = &shellquote . a:cmd . &shellquote
  if has('win32') && &shellxquote =~# '^"\=($'
    return &shell . ' ' . &shellcmdflag . ' ' . &shellxquote . l:cmd . (&shellxquote ==# '(' ? ')' : ')"')
  endif
  return [substitute(&shell, '^"\|"$', '', 'g'), &shellcmdflag, l:cmd]
endfunction

function! s:start(request) abort
  let l:build = extend({'lines': [], 'closed': 0, 'exited': 0, 'status': 0, 'started': reltime()}, a:request)
  " Its input is a pipe closed at once, an end of input like :make's. A null
  " device is not: Lake, given one, fails as it starts Lean ("LEAN ASSERTION
  " VIOLATION" in process.cpp).
  let l:build.job = job_start(s:shell(l:build.cmd), {'cwd': l:build.dir, 'err_io': 'out',
    \ 'out_cb': function('s:output', [l:build]),
    \ 'close_cb': function('s:closed', [l:build]),
    \ 'exit_cb': function('s:exited', [l:build])})
  if job_status(l:build.job) ==# 'fail'
    call s:warn('could not start ' . &shell)
    return
  endif
  call ch_close_in(l:build.job)
  let s:build = l:build
endfunction

function! s:output(build, channel, line) abort
  call add(a:build.lines, substitute(a:line, '\r$', '', ''))
endfunction

" The output and the exit status arrive separately and in either order.
function! s:closed(build, channel) abort
  let a:build.closed = 1
  call s:finish(a:build)
endfunction

function! s:exited(build, job, status) abort
  " Not told by the status itself: one below zero is what "exit -1" gives on
  " Windows, and a program that crashed.
  let [a:build.exited, a:build.status] = [1, a:status]
  call s:finish(a:build)
endfunction

" Vim marks an entry with no file invalid, and :clist hides invalid entries:
" TeX's "! message", which has no file, would never be seen. It is put on the
" buffer that was built, so that :clist shows it and :cc goes there. (If it
" is still there: setqflist() refuses the number of a buffer that was wiped.)
function! s:entry(build, item) abort
  if !a:item.bufnr && bufexists(a:build.buffer)
    let a:item.bufnr = a:build.buffer
  endif
  let a:item.valid = 1
  return a:item
endfunction

" :make fires QuickFixCmdPost once the list is filled, and what listens may
" fix it up there: Lean's columns, for one. It runs with the buffer that was
" built as the current one, as for :make, in a window that shows it, or in a
" hidden popup when none does. A handler that fails costs nothing but itself.
function! s:post(buffer) abort
  if !exists('#QuickFixCmdPost#make') || !bufexists(a:buffer)
    return
  endif
  let l:wins = win_findbuf(a:buffer)
  let l:popup = 0
  try
    if empty(l:wins)
      call bufload(a:buffer)
      let l:popup = popup_create(a:buffer, {'hidden': 1})
      let l:wins = [l:popup]
    endif
    call win_execute(l:wins[0], 'doautocmd <nomodeline> QuickFixCmdPost make')
  catch
    call s:warn('QuickFixCmdPost: ' . substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', ''))
  finally
    if l:popup
      call popup_close(l:popup)
    endif
  endtry
endfunction

function! s:finish(build) abort
  if !a:build.closed || !a:build.exited
    return
  endif
  let s:build = {}
  " Read with the 'errorformat' of the buffer that started the build, and
  " from the folder it ran in: by now the current buffer and directory may be
  " anything. %D is how make's "Entering directory" lines are followed, and
  " it leaves that line in the list, so [1:] takes it out again.
  let l:items = getqflist({'efm': "%DEntering directory '%f'," . a:build.efm,
    \ 'lines': ["Entering directory '" . a:build.dir . "'"] + a:build.lines}).items[1:]
  " With a final %-G%.%# every line left is an error. Without one, the lines
  " 'errorformat' does not know are in the list too, and stay invalid.
  if a:build.efm =~# '%-G%\.%#$'
    call map(l:items, {_, item -> s:entry(a:build, item)})
  endif
  let l:errors = len(filter(copy(l:items), 'v:val.valid'))
  let l:took = printf('%.1f s', reltimefloat(reltime(a:build.started)))
  if a:build.status != 0 && !l:errors
    " It failed in a way 'errorformat' does not know: list what it said.
    " Not [-12:]: that is empty for a list shorter than 12.
    let l:tail = a:build.lines[max([0, len(a:build.lines) - 12]) :]
    let l:items = map(l:tail, {_, line -> s:entry(a:build, {'bufnr': 0, 'text': line})})
    echohl ErrorMsg | echomsg 'make failed (' . l:took . '), :clist for its output' | echohl None
  elseif l:errors
    echohl ErrorMsg
    echomsg 'make: ' . l:errors . (l:errors == 1 ? ' error' : ' errors') . ' (' . l:took . '), :clist to see them'
    echohl None
  else
    echo 'make done (' . l:took . ')'
  endif
  call setqflist([], ' ', {'title': a:build.cmd, 'items': l:items})
  call s:post(a:build.buffer)
  if !empty(s:next)
    let l:next = s:next
    let s:next = {}
    call s:start(l:next)
  endif
endfunction
