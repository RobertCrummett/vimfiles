" The build behind plugin/bgmake.vim.
"
" A :make during a build does not stop it. Killing latexmk can leave a
" half-written PDF or .aux behind, so one more build follows instead.

let s:build = {}      " the running build, or empty
let s:again = []      " a :make came during it: what s:start() takes for it

" 'statusline' can show this.
function! bgmake#running() abort
  return !empty(s:build)
endfunction

function! bgmake#make(timer) abort
  if empty(bufname('%'))
    call s:warn('this buffer has no file to make')
    return
  endif
  " :make on a stale file is a trap, as in matlabserver#make().
  if &modified
    silent update
  endif
  let l:args = [expandcmd(&makeprg), &errorformat, getcwd(), bufnr('%')]
  if !empty(s:build)
    " Of this buffer, which need not be the one that is being built.
    let s:again = l:args
    echo 'make: one more build after this one'
    return
  endif
  call call('s:start', l:args)
  if !empty(s:build)
    echo 'make: building'
  endif
endfunction

function! s:warn(message) abort
  echohl ErrorMsg | echomsg 'bgmake: ' . a:message | echohl None
endfunction

function! s:start(cmd, efm, dir, buffer) abort
  let l:build = {'cmd': a:cmd, 'efm': a:efm, 'dir': a:dir, 'buffer': a:buffer,
    \ 'lines': [], 'closed': 0, 'exited': 0, 'status': 0, 'started': reltime()}
  " The shell runs it, as for :make itself. 'shell' may carry its own quotes.
  let l:argv = [substitute(&shell, '^"\|"$', '', 'g'), &shellcmdflag, a:cmd]
  let l:build.job = job_start(l:argv, {'cwd': a:dir, 'in_io': 'null', 'err_io': 'out',
    \ 'out_cb': function('s:output', [l:build]),
    \ 'close_cb': function('s:closed', [l:build]),
    \ 'exit_cb': function('s:exited', [l:build])})
  if job_status(l:build.job) ==# 'fail'
    call s:warn('could not start ' . l:argv[0])
    return
  endif
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
  if !empty(s:again)
    let [l:args, s:again] = [s:again, []]
    call call('s:start', l:args)
  endif
endfunction
