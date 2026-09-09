" Matlab needs about five seconds to start, so asking it a question per
" lookup is not an option. matlab/build_index.m runs it once and writes
" every documented function's help text to matlab/index/, and a lookup is
" then a file read. Matlab is only started again to rebuild that index, or for
" a name it does not cover.
"
" Reading the .m files under matlabroot directly would be faster still but
" wrong: most core functions are compiled with no .m file at all, and the
" basename that does exist is usually a class method overload - exp.m under
" @tabular, plot.m under @tall - whose help is not the help you wanted.

" vimfiles itself. Resolved here and not inside a function: <sfile> names the
" sourced script only at script level, and the running function inside one.
let s:root = expand('<sfile>:p:h:h')

let s:cache = {}       " name -> lines, for answers Matlab was asked for live
let s:job = v:null
let s:want = {}        " the live request in flight: name, key, lines
let s:lastdir = ''     " the last real file's directory, for lookups made
                       " from a scratch buffer
let s:seq = 0          " request number, so a reply that arrives after its
                       " request was replaced can be told apart

" ------------------------------------------------------------ matlab

" Which matlab.exe to run. An explicit setting wins, then $PATH, then the
" newest release installed in the default location.
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

" Matlab resolves names against its own current directory, so start it in the
" directory of the file being read to reach the .m files sitting beside it.
"
" The report window is a scratch buffer with no file of its own, and so is
" matlabserver's output window, where K on a function your code named is the
" whole point. Taking expand('%:p:h') there gives Vim's own directory and the
" answer comes back "not found", so the directory of the last file a lookup
" was made from is remembered and used instead.
function! s:startdir() abort
  if empty(&buftype) && !empty(bufname('%'))
    let l:dir = expand('%:p:h')
    if isdirectory(l:dir)
      let s:lastdir = l:dir
      return l:dir
    endif
  endif
  return isdirectory(s:lastdir) ? s:lastdir : getcwd()
endfunction

function! s:dir() abort
  return s:root . '/matlab'
endfunction

function! s:index_dir() abort
  return s:dir() . '/index'
endfunction

" ------------------------------------------------------------- report

function! s:show(name, source, lines) abort
  let l:title = 'Matlab help ' . a:name
  let l:win = 0
  for l:w in range(1, winnr('$'))
    if getbufvar(winbufnr(l:w), 'matlabdoc_report', 0)
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
  let b:matlabdoc_report = 1
  let l:n = 0
  let l:try = '[' . l:title . ']'
  while bufexists(l:try)
    let l:n += 1
    let l:try = '[' . l:title . ' ' . l:n . ']'
  endwhile
  execute 'silent keepalt file' fnameescape(l:try)
  call setline(1, a:lines + ['', repeat('-', 70), 'source: ' . a:source])
  setlocal nomodified nomodifiable
  setlocal filetype=matlabout
  normal! gg
endfunction

" ------------------------------------------------------------- index

" The help text for {name} out of the built index, or [] when it has none.
function! s:from_index(name) abort
  let l:file = s:index_dir() . '/' . tolower(a:name) . '.txt'
  return filereadable(l:file) ? readfile(l:file) : []
endfunction

" Where an index entry came from: the build, or a lookup that added it since.
function! s:index_source(name) abort
  let l:file = s:index_dir() . '/' . tolower(a:name) . '.txt'
  let l:stamp = getftime(s:index_dir() . '/.stamp')
  if l:stamp < 0 || getftime(l:file) <= l:stamp
    return 'index, built ' . s:built_when()
  endif
  return 'index, added ' . strftime('%Y-%m-%d %H:%M', getftime(l:file))
endfunction

" ----------------------------------------------------------- live answers

" The marker after which a live lookup reports where Matlab found the name.
let s:which = '--MATLABDOC-WHICH--'

" The Matlab statement for a live lookup: the help text, then one line with
" which() so the answer can be filed by where it came from.
function! s:help_cmd(name) abort
  return printf("help('%s'); disp(['%s ' which('%s')])", a:name, s:which, a:name)
endfunction

" Take the which() line off a live answer: [help lines, path or ''].
function! s:split_which(lines) abort
  let l:lines = copy(a:lines)
  let l:path = ''
  let l:i = len(l:lines) - 1
  while l:i >= 0
    if l:lines[l:i] =~# '^' . s:which
      let l:path = trim(strpart(l:lines[l:i], len(s:which)))
      call remove(l:lines, l:i)
      break
    endif
    let l:i -= 1
  endwhile
  while !empty(l:lines) && empty(trim(l:lines[-1]))
    call remove(l:lines, -1)
  endwhile
  return [l:lines, l:path]
endfunction

function! s:matlabroot() abort
  let l:stamp = s:index_dir() . '/.stamp'
  if filereadable(l:stamp)
    for l:line in readfile(l:stamp)
      if l:line =~# '^matlabroot '
        return substitute(l:line, '^matlabroot ', '', '')
      endif
    endfor
  endif
  let l:exe = s:program()
  return empty(l:exe) ? '' : fnamemodify(l:exe, ':h:h')
endfunction

" Keep a live answer. "x not found." is never kept: the name may resolve
" once the file is saved or the path changes. Anything else is remembered
" for the session, and when which() places it under matlabroot, a toolbox
" function the build missed, it goes into the index on disk as well, so no
" later session has to ask again. Your own functions stay out of the index:
" their help changes as you edit them.
function! s:remember(name, key, lines, path) abort
  if empty(a:lines) || a:lines[0] =~# ' not found\.$'
    return ''
  endif
  let s:cache[a:key] = a:lines
  let l:root = s:matlabroot()
  if empty(a:path) || empty(l:root)
    return ''
  endif
  let l:Norm = {p -> tolower(substitute(p, '\\', '/', 'g'))}
  if stridx(l:Norm(a:path), l:Norm(l:root)) < 0
    return ''
  endif
  if !isdirectory(s:index_dir())
    call mkdir(s:index_dir(), 'p')
  endif
  call writefile(a:lines, s:index_dir() . '/' . tolower(a:name) . '.txt')
  return ', added to the index'
endfunction

function! matlabdoc#index_status() abort
  let l:stamp = s:index_dir() . '/.stamp'
  if !filereadable(l:stamp)
    echo 'matlabdoc: no index yet; run :MatlabDocIndex (about a minute and a half, once)'
    return
  endif
  let l:n = len(glob(s:index_dir() . '/*.txt', 0, 1))
  echo 'matlabdoc: ' . l:n . ' functions indexed'
  for l:line in readfile(l:stamp)
    echo '  ' . l:line
  endfor
endfunction

function! s:index_done(job, status) abort
  " Only the job still on the books may clear what is on the books; an exit
  " that arrives after this one was replaced has nothing left to say.
  if a:job isnot s:job
    return
  endif
  let s:job = v:null
  let s:want = {}
  redraw
  if a:status
    echohl ErrorMsg
    echomsg 'matlabdoc: index build failed (exit ' . a:status . '); see '
      \ . s:dir() . '/build.log'
    echohl NONE
    return
  endif
  let l:n = len(glob(s:index_dir() . '/*.txt', 0, 1))
  echomsg 'matlabdoc: indexed ' . l:n . ' functions; lookups are instant now'
endfunction

function! matlabdoc#index() abort
  let l:exe = s:program()
  if empty(l:exe)
    echohl ErrorMsg
    echomsg 'matlabdoc: no matlab.exe found; set g:matlabdoc_program'
    echohl NONE
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    echohl WarningMsg
    echomsg 'matlabdoc: a Matlab job is already running'
    echohl NONE
    return
  endif
  let s:want = {}
  let s:job = job_start([l:exe, '-sd', s:dir(), '-batch', "build_index('index')"],
    \ {'in_io': 'null', 'out_io': 'file', 'out_name': s:dir() . '/build.log',
    \  'err_io': 'out', 'exit_cb': function('s:index_done')})
  if job_status(s:job) !=# 'run'
    let s:job = v:null
    echohl ErrorMsg
    echomsg 'matlabdoc: could not run ' . l:exe
    echohl NONE
    return
  endif
  echo 'matlabdoc: building the index in the background, about a minute and a half; '
    \ . 'carry on, you will be told when it is done'
endfunction

" ------------------------------------------------------------ lookup

" Called with the request number bound, because a job is only refused while
" it is running: a lookup asked for between one finishing and its exit
" callback running starts a second job, and the first callback would then
" show its own answer and throw the second request's away.
function! s:live_done(id, job, status) abort
  let l:w = s:want
  if get(l:w, 'id', -1) != a:id
    return
  endif
  let s:job = v:null
  let s:want = {}
  while !empty(l:w.lines) && empty(trim(l:w.lines[-1]))
    call remove(l:w.lines, -1)
  endwhile
  redraw
  if empty(l:w.lines)
    echohl WarningMsg
    echomsg 'matlabdoc: matlab said nothing about ' . l:w.name
      \ . (a:status ? ' (exit ' . a:status . ')' : '')
    echohl NONE
    return
  endif
  let [l:lines, l:path] = s:split_which(l:w.lines)
  let l:filed = s:remember(l:w.name, l:w.key, l:lines, l:path)
  echo ''
  call s:show(l:w.name, 'matlab -batch, just now' . l:filed, l:lines)
endfunction

" Same guard: Vim may deliver a job's last output after its exit callback, and
" that tail must not be appended to the answer of whatever was asked next.
function! s:collect(id, ch, msg) abort
  if get(s:want, 'id', -1) == a:id
    call add(s:want.lines, substitute(a:msg, '\r$', '', ''))
  endif
endfunction

" Ask Matlab itself. Only reached for names the index does not cover, which
" in practice means functions you wrote.
function! s:live(name) abort
  let l:exe = s:program()
  if empty(l:exe)
    echohl ErrorMsg
    echomsg 'matlabdoc: no matlab.exe found; set g:matlabdoc_program'
    echohl NONE
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    echohl WarningMsg
    echomsg 'matlabdoc: a Matlab job is already running; try again in a moment'
    echohl NONE
    return
  endif
  let l:key = s:startdir() . "\n" . a:name
  let s:seq += 1
  let s:want = {'id': s:seq, 'name': a:name, 'key': l:key, 'lines': []}
  " A list, not a string: Vim passes the arguments through without a shell, so
  " the name needs no quoting. -batch keeps Matlab headless and exits after.
  let s:job = job_start([l:exe, '-sd', s:startdir(), '-batch', s:help_cmd(a:name)],
    \ {'in_io': 'null', 'out_cb': function('s:collect', [s:seq]),
    \  'err_cb': function('s:collect', [s:seq]),
    \  'exit_cb': function('s:live_done', [s:seq])})
  if job_status(s:job) !=# 'run'
    let s:job = v:null
    let s:want = {}
    echohl ErrorMsg
    echomsg 'matlabdoc: could not run ' . l:exe
    echohl NONE
    return
  endif
  echo 'matlabdoc: ' . a:name . ' is not in the index; asking Matlab (a few seconds) ...'
endfunction

function! matlabdoc#open(name) abort
  let l:name = empty(a:name) ? expand('<cword>') : a:name
  if l:name !~# '^\a\w*$'
    echohl WarningMsg
    echomsg 'matlabdoc: not a name Matlab can look up: ' . l:name
    echohl NONE
    return
  endif

  " Where the lookup was made from, noted before the index answers and
  " returns: a K in the report window that follows this one has no file of
  " its own to take a directory from, and s:startdir() remembers this.
  let l:dir = s:startdir()

  let l:lines = s:from_index(l:name)
  if !empty(l:lines)
    call s:show(l:name, s:index_source(l:name), l:lines)
    return
  endif

  let l:key = l:dir . "\n" . l:name
  if has_key(s:cache, l:key)
    call s:show(l:name, 'answered earlier this session', s:cache[l:key])
    return
  endif

  " A warm matlabserver session answers in milliseconds; matlab -batch is
  " the five second road taken only when there is none.
  let l:answer = s:from_session(l:name, l:dir)
  if !empty(l:answer)
    let [l:lines, l:path] = s:split_which(l:answer)
    let l:filed = s:remember(l:name, l:key, l:lines, l:path)
    call s:show(l:name, 'the Matlab session, just now' . l:filed, l:lines)
    return
  endif

  call s:live(l:name)
endfunction

" Ask the running matlabserver session, or return [] when there is none or
" it does not answer in time (then the caller starts matlab -batch).
"
" help() resolves a name against the session's current directory, and the
" session's is wherever the last :MatlabRun left it, so the lookup steps
" into the file's directory and back. The variable that carries the old
" directory lives in the base workspace next to the user's; the name is
" chosen to collide with nothing and cleared again.
function! s:from_session(name, dir) abort
  if !exists('*matlabserver#running') || !matlabserver#running()
    return []
  endif
  let l:cmd = printf("matlabdoc_pwd__ = pwd; cd('%s'); %s; cd(matlabdoc_pwd__); clear matlabdoc_pwd__",
    \ substitute(a:dir, "'", "''", 'g'), s:help_cmd(a:name))
  let l:res = matlabserver#eval_sync(l:cmd, get(g:, 'matlabdoc_session_timeout', 5000))
  return l:res.ok ? l:res.lines : []
endfunction

function! s:built_when() abort
  let l:stamp = s:index_dir() . '/.stamp'
  if !filereadable(l:stamp)
    return 'unknown'
  endif
  for l:line in readfile(l:stamp)
    if l:line =~# '^built '
      return substitute(l:line, '^built ', '', '')
    endif
  endfor
  return 'unknown'
endfunction

function! matlabdoc#clear() abort
  let l:n = len(s:cache)
  let s:cache = {}
  echo printf('matlabdoc: forgot %d live answer%s (the index is untouched)',
    \ l:n, l:n == 1 ? '' : 's')
endfunction
