" Registry of entries seen in listings: id -> {'path': ..., 'isdir': ...}.
" Ids are global so a line pasted into another listing still identifies the
" file it came from (that is how moves between directories work).
let s:entries = {}
let s:by_path = {}
let s:next_id = 1

" ---------------------------------------------------------------- paths

" Full path with forward slashes and no trailing slash (roots keep theirs).
function! diredit#normalize(path) abort
  let l:p = fnamemodify(a:path, ':p')
  let l:p = substitute(l:p, '\\', '/', 'g')
  if l:p !~# '^[A-Za-z]:/$' && l:p !=# '/'
    let l:p = substitute(l:p, '/\+$', '', '')
  endif
  return l:p
endfunction

function! s:join(dir, name) abort
  return a:dir =~# '/$' ? a:dir . a:name : a:dir . '/' . a:name
endfunction

function! s:is_absolute(name) abort
  return a:name =~# '^/' || a:name =~# '^[A-Za-z]:/'
endfunction

function! s:exists(path) abort
  return filereadable(a:path) || isdirectory(a:path) || getftype(a:path) !=# ''
endfunction

function! s:bufdir() abort
  return substitute(bufname(''), '^diredit://', '', '')
endfunction

" ------------------------------------------------------------- registry

function! s:register(path, isdir) abort
  if has_key(s:by_path, a:path)
    let l:id = s:by_path[a:path]
    let s:entries[l:id].isdir = a:isdir
    return l:id
  endif
  let l:id = s:next_id
  let s:next_id += 1
  let s:entries[l:id] = {'path': a:path, 'isdir': a:isdir}
  let s:by_path[a:path] = l:id
  return l:id
endfunction

function! s:forget(path) abort
  if has_key(s:by_path, a:path)
    call remove(s:entries, s:by_path[a:path])
    call remove(s:by_path, a:path)
  endif
endfunction

" --------------------------------------------------------------- opening

function! diredit#open(dir) abort
  if empty(a:dir)
    if exists('b:diredit_dir')
      let l:dir = fnamemodify(b:diredit_dir, ':h')
    elseif empty(expand('%')) || &buftype !=# ''
      let l:dir = getcwd()
    else
      let l:dir = expand('%:p:h')
    endif
  else
    let l:dir = a:dir
  endif
  let l:dir = diredit#normalize(l:dir)
  if !isdirectory(l:dir)
    return s:error('Not a directory: ' . l:dir)
  endif
  execute 'edit' fnameescape('diredit://' . l:dir)
endfunction

function! diredit#open_parent() abort
  if exists('b:diredit_dir')
    let l:from = b:diredit_dir
    let l:dir = fnamemodify(l:from, ':h')
  elseif empty(expand('%')) || &buftype !=# ''
    let l:from = ''
    let l:dir = getcwd()
  else
    let l:from = expand('%:p')
    let l:dir = expand('%:p:h')
  endif
  call diredit#open(l:dir)
  " Put the cursor on the entry we came from.
  if !empty(l:from) && exists('b:diredit_dir')
    let l:from = diredit#normalize(l:from)
    for l:lnum in range(1, line('$'))
      let l:e = s:parse(getline(l:lnum), l:lnum)
      if !empty(l:e) && l:e.id && has_key(s:entries, l:e.id)
            \ && s:entries[l:e.id].path ==# l:from
        call cursor(l:lnum, 1)
        break
      endif
    endfor
  endif
endfunction

" Replace a buffer that is really a directory with a listing.
function! diredit#hijack(name) abort
  if empty(a:name) || a:name =~# '^diredit://' || !isdirectory(a:name)
    return
  endif
  let l:old = bufnr('%')
  call diredit#open(a:name)
  if bufnr('%') != l:old
    execute 'silent! bwipeout' l:old
  endif
endfunction

" Open the entry under the cursor.
function! diredit#select() abort
  let l:e = s:parse(getline('.'), line('.'))
  if empty(l:e)
    return
  endif
  if !l:e.id || !has_key(s:entries, l:e.id)
    return s:error('This entry is not on disk yet; :w first')
  endif
  let l:path = s:entries[l:e.id].path
  if isdirectory(l:path)
    call diredit#open(l:path)
  else
    execute 'edit' fnameescape(l:path)
  endif
endfunction

function! diredit#toggle_hidden() abort
  let g:diredit_show_hidden = !g:diredit_show_hidden
  call diredit#render()
endfunction

function! diredit#help() abort
  echo join([
    \ '<CR>  open entry        -   parent directory    R   reload',
    \ 'g.    toggle dotfiles   gl  toggle details      g?  this help',
    \ 'Edit the listing, then :w applies it:',
    \ '  rename: change the name        delete: dd the line',
    \ '  copy:   yy then p, edit name   move:   write sub/name or a full path',
    \ '  create: add a line; end it with / for a directory',
    \ ], "\n")
endfunction

" ------------------------------------------------------------- rendering

function! diredit#render() abort
  let l:dir = s:bufdir()
  let b:diredit_dir = l:dir
  setlocal buftype=acwrite bufhidden=hide noswapfile nobuflisted
  " Setting 'filetype' again would re-run the ftplugin (and its undo).
  if &filetype !=# 'diredit'
    setlocal filetype=diredit
  endif

  try
    let l:names = readdir(l:dir)
  catch
    let l:names = []
    call s:error('Cannot read ' . l:dir . ': ' . v:exception)
  endtry
  if !g:diredit_show_hidden
    call filter(l:names, 'v:val !~# "^\\."')
  endif

  let l:items = []
  for l:name in l:names
    let l:path = s:join(l:dir, l:name)
    call add(l:items, {'name': l:name, 'path': l:path, 'isdir': isdirectory(l:path)})
  endfor
  call sort(l:items, function('s:compare'))

  " Each line is "id<Tab>details<Tab>name". Both tabs are concealed and
  " the details field is padded, so the names line up like ls/dir output.
  " Only the first and last fields matter when the listing is written.
  let l:lines = []
  let b:diredit_ids = []
  for l:it in l:items
    let l:id = s:register(l:it.path, l:it.isdir)
    call add(b:diredit_ids, l:id)
    let l:details = g:diredit_details ? s:details(l:it.path, l:it.isdir) . "\t" : ''
    call add(l:lines, printf('%05d', l:id) . "\t" . l:details . l:it.name . (l:it.isdir ? '/' : ''))
  endfor

  let l:view = winsaveview()
  setlocal modifiable
  silent %delete _
  call setline(1, l:lines)
  call winrestview(l:view)
  setlocal nomodified
endfunction

" Human readable size: bytes below 1K, then one decimal up to 9.9, then
" whole units, always right-aligned in 6 columns.
function! s:human_size(bytes) abort
  let l:n = a:bytes
  for l:unit in ['', 'K', 'M', 'G', 'T']
    if l:n < 1024 || l:unit ==# 'T'
      if empty(l:unit)
        return printf('%6d', l:n)
      endif
      return printf('%6s', (l:n < 10 ? printf('%.1f', l:n) : printf('%d', float2nr(round(l:n)))) . l:unit)
    endif
    let l:n = l:n / 1024.0
  endfor
endfunction

" The details column: [permissions] date time size.
function! s:details(path, isdir) abort
  let l:type = getftype(a:path)
  if a:isdir
    let l:size = ' <DIR>'
  elseif l:type ==# 'link'
    let l:size = ' <LNK>'
  else
    let l:sz = getfsize(a:path)
    let l:size = l:sz < 0 ? '     ?' : s:human_size(l:sz)
  endif
  let l:time = getftime(a:path)
  let l:when = l:time < 0 ? '               ?' : strftime('%Y-%m-%d %H:%M', l:time)
  let l:perm = has('win32') ? '' : (empty(getfperm(a:path)) ? '----------' : (a:isdir ? 'd' : l:type ==# 'link' ? 'l' : '-') . getfperm(a:path)) . '  '
  return l:perm . l:when . '  ' . l:size . '  '
endfunction

function! diredit#toggle_details() abort
  let g:diredit_details = !g:diredit_details
  call diredit#render()
endfunction

" Directories first, then case-insensitive by name.
function! s:compare(a, b) abort
  if a:a.isdir != a:b.isdir
    return a:a.isdir ? -1 : 1
  endif
  let l:x = tolower(a:a.name)
  let l:y = tolower(a:b.name)
  return l:x ==# l:y ? 0 : (l:x <# l:y ? -1 : 1)
endfunction

" --------------------------------------------------------------- parsing

" One listing line -> {'id': n (0 if new), 'name': ..., 'isdir': hint,
" 'lnum': n}, or {} for a blank line.
function! s:parse(line, lnum) abort
  if a:line =~# '^\s*$'
    return {}
  endif
  " "id<Tab>details<Tab>name", "id<Tab>name" (details deleted), or just a
  " name for a new entry. Anything between the first and last tab is
  " display only.
  let l:fields = split(a:line, "\t", 1)
  if len(l:fields) >= 2 && l:fields[0] =~# '^\d\+$'
    let l:id = str2nr(l:fields[0])
    let l:name = l:fields[-1]
  else
    let l:id = 0
    let l:name = a:line
  endif
  let l:name = substitute(l:name, '\\', '/', 'g')
  let l:name = trim(l:name)
  let l:isdir = l:name =~# '/$'
  let l:name = substitute(l:name, '/\+$', '', '')
  return {'id': l:id, 'name': l:name, 'isdir': l:isdir, 'lnum': a:lnum}
endfunction

function! s:validate_name(name) abort
  if empty(a:name)
    return 'empty name'
  endif
  for l:part in split(a:name, '/')
    if l:part ==# '.' || l:part ==# '..'
      return '"' . l:part . '" is not allowed in a name'
    endif
  endfor
  let l:body = has('win32') ? substitute(a:name, '^[A-Za-z]:', '', '') : a:name
  if has('win32') && l:body =~# '[<>:"|?*]'
    return 'invalid character in "' . a:name . '"'
  endif
  if l:body =~# '[[:cntrl:]]'
    return 'invalid character in "' . a:name . '"'
  endif
  return ''
endfunction

" Ids present in other loaded listings. An entry missing here but present
" there is a move, which that listing applies when it is written.
function! s:ids_elsewhere() abort
  let l:ids = {}
  for l:buf in getbufinfo()
    if l:buf.bufnr == bufnr('%') || !has_key(l:buf.variables, 'diredit_dir')
      continue
    endif
    for l:line in getbufline(l:buf.bufnr, 1, '$')
      let l:e = s:parse(l:line, 0)
      if !empty(l:e) && l:e.id
        let l:ids[l:e.id] = 1
      endif
    endfor
  endfor
  return l:ids
endfunction

" ---------------------------------------------------------------- planning

" Returns {'ops': [...], 'errors': [...]}. Each op is
" {'op': 'delete'|'move'|'copy'|'create', 'src': ..., 'dest': ..., 'isdir': ...}.
function! s:plan() abort
  let l:dir = b:diredit_dir
  let l:errors = []
  let l:seen = {}       " id -> [{'dest': ..., 'lnum': ...}, ...]
  let l:order = []      " ids in listing order
  let l:creates = []

  for l:lnum in range(1, line('$'))
    let l:e = s:parse(getline(l:lnum), l:lnum)
    if empty(l:e)
      continue
    endif
    let l:err = s:validate_name(l:e.name)
    if !empty(l:err)
      call add(l:errors, printf('line %d: %s', l:lnum, l:err))
      continue
    endif
    let l:dest = s:is_absolute(l:e.name) ? diredit#normalize(l:e.name) : s:join(l:dir, l:e.name)
    if l:e.id == 0
      call add(l:creates, {'op': 'create', 'src': '', 'dest': l:dest, 'isdir': l:e.isdir, 'lnum': l:lnum})
    elseif !has_key(s:entries, l:e.id)
      call add(l:errors, printf('line %d: unknown entry id %d (reload with :e!)', l:lnum, l:e.id))
    else
      if !has_key(l:seen, l:e.id)
        let l:seen[l:e.id] = []
        call add(l:order, l:e.id)
      endif
      call add(l:seen[l:e.id], {'dest': l:dest, 'lnum': l:lnum})
    endif
  endfor

  let l:ops = []
  " Entries that were listed here and are now gone.
  let l:elsewhere = {}
  let l:checked_elsewhere = 0
  for l:id in b:diredit_ids
    if has_key(l:seen, l:id) || !has_key(s:entries, l:id)
      continue
    endif
    if !l:checked_elsewhere
      let l:elsewhere = s:ids_elsewhere()
      let l:checked_elsewhere = 1
    endif
    if !has_key(l:elsewhere, l:id)
      call add(l:ops, {'op': 'delete', 'src': s:entries[l:id].path, 'dest': '',
        \ 'isdir': s:entries[l:id].isdir, 'lnum': 0})
    endif
  endfor

  " Entries present here: unchanged, renamed/moved, or copied. The first
  " line that keeps the original path is the original; otherwise the first
  " line is a move. Every other line with the same id is a copy.
  for l:id in l:order
    let l:entry = s:entries[l:id]
    let l:dests = l:seen[l:id]
    let l:kept = !empty(filter(copy(l:dests), 'v:val.dest ==# l:entry.path'))
    let l:original_seen = 0
    let l:moved = 0
    for l:d in l:dests
      if l:d.dest ==# l:entry.path
        if l:original_seen
          call add(l:ops, {'op': 'copy', 'src': l:entry.path, 'dest': l:d.dest,
            \ 'isdir': l:entry.isdir, 'lnum': l:d.lnum})
        endif
        let l:original_seen = 1
      elseif !l:kept && !l:moved
        call add(l:ops, {'op': 'move', 'src': l:entry.path, 'dest': l:d.dest,
          \ 'isdir': l:entry.isdir, 'lnum': l:d.lnum})
        let l:moved = 1
      else
        call add(l:ops, {'op': 'copy', 'src': l:entry.path, 'dest': l:d.dest,
          \ 'isdir': l:entry.isdir, 'lnum': l:d.lnum})
      endif
    endfor
  endfor
  call extend(l:ops, l:creates)

  " Destinations must be unique, and must not exist on disk unless the
  " occupant is itself being deleted or moved away by this plan.
  let l:vacated = {}
  for l:op in l:ops
    if l:op.op ==# 'delete' || l:op.op ==# 'move'
      let l:vacated[l:op.src] = 1
    endif
  endfor
  let l:dests = {}
  for l:op in l:ops
    if l:op.op ==# 'delete'
      continue
    endif
    if has_key(l:dests, l:op.dest)
      call add(l:errors, printf('line %d: "%s" is used twice', l:op.lnum, l:op.dest))
    endif
    let l:dests[l:op.dest] = 1
    if s:exists(l:op.dest) && !has_key(l:vacated, l:op.dest)
      call add(l:errors, printf('line %d: "%s" already exists', l:op.lnum, l:op.dest))
    endif
    if l:op.isdir && !empty(l:op.src) && stridx(l:op.dest . '/', l:op.src . '/') == 0
      call add(l:errors, printf('line %d: cannot put "%s" inside itself', l:op.lnum, l:op.src))
    endif
  endfor
  return {'ops': l:ops, 'errors': l:errors}
endfunction

function! s:describe(op) abort
  if a:op.op ==# 'delete'
    return 'DELETE ' . a:op.src . (a:op.isdir ? '/ (recursively)' : '')
  elseif a:op.op ==# 'create'
    return 'CREATE ' . a:op.dest . (a:op.isdir ? '/' : '')
  else
    return toupper(a:op.op) . '   ' . a:op.src . ' -> ' . a:op.dest
  endif
endfunction

" ---------------------------------------------------------------- applying

function! s:copy_path(src, dest, isdir) abort
  if a:isdir
    if !isdirectory(a:dest)
      call mkdir(a:dest, 'p')
    endif
    for l:name in readdir(a:src)
      let l:s = s:join(a:src, l:name)
      if s:copy_path(l:s, s:join(a:dest, l:name), isdirectory(l:s)) != 0
        return -1
      endif
    endfor
    return 0
  endif
  if exists('*filecopy')
    return filecopy(a:src, a:dest) ? 0 : -1
  endif
  try
    return writefile(readfile(a:src, 'b'), a:dest, 'b')
  catch
    return -1
  endtry
endfunction

function! s:ensure_parent(path) abort
  let l:parent = fnamemodify(a:path, ':h')
  if !isdirectory(l:parent)
    call mkdir(l:parent, 'p')
  endif
endfunction

" Runs one op; returns '' on success or a reason.
function! s:execute(op) abort
  try
    if a:op.op ==# 'delete'
      if delete(a:op.src, a:op.isdir ? 'rf' : '') != 0
        return 'could not delete'
      endif
      call s:forget(a:op.src)
    elseif a:op.op ==# 'move'
      call s:ensure_parent(a:op.dest)
      if rename(a:op.src, a:op.dest) != 0
        " rename() cannot cross devices; fall back to copy and delete.
        if s:copy_path(a:op.src, a:op.dest, a:op.isdir) != 0
              \ || delete(a:op.src, a:op.isdir ? 'rf' : '') != 0
          return 'could not move'
        endif
      endif
      call s:forget(a:op.src)
    elseif a:op.op ==# 'copy'
      call s:ensure_parent(a:op.dest)
      if s:copy_path(a:op.src, a:op.dest, a:op.isdir) != 0
        return 'could not copy'
      endif
    elseif a:op.op ==# 'create'
      if a:op.isdir
        call mkdir(a:op.dest, 'p')
      else
        call s:ensure_parent(a:op.dest)
        if writefile([], a:op.dest) != 0
          return 'could not create'
        endif
      endif
    endif
  catch
    return substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
  endtry
  return ''
endfunction

" Moves and copies can depend on each other (a -> b while b -> a, or a
" copy of a file that is also being renamed). Run whatever is unblocked;
" break cycles by parking a source under a temporary name.
function! s:execute_transfers(ops) abort
  let l:pending = copy(a:ops)
  let l:failures = []
  let l:tmp_n = 0
  while !empty(l:pending)
    let l:progress = 0
    for l:op in copy(l:pending)
      if s:exists(l:op.dest)
        continue
      endif
      if l:op.op ==# 'move' && !empty(filter(copy(l:pending),
            \ 'v:val.op ==# "copy" && v:val.src ==# l:op.src'))
        continue
      endif
      let l:err = s:execute(l:op)
      if !empty(l:err)
        call add(l:failures, s:describe(l:op) . ': ' . l:err)
      endif
      call remove(l:pending, index(l:pending, l:op))
      let l:progress = 1
    endfor
    if l:progress
      continue
    endif
    " Everything left is blocked: park the first move's source.
    let l:moves = filter(copy(l:pending), 'v:val.op ==# "move"')
    if empty(l:moves)
      for l:op in l:pending
        call add(l:failures, s:describe(l:op) . ': destination is occupied')
      endfor
      break
    endif
    let l:src = l:moves[0].src
    let l:tmp_n += 1
    let l:tmp = l:src . '.diredit-tmp-' . l:tmp_n
    if rename(l:src, l:tmp) != 0
      call add(l:failures, s:describe(l:moves[0]) . ': could not use a temporary name')
      call remove(l:pending, index(l:pending, l:moves[0]))
      continue
    endif
    for l:op in l:pending
      if l:op.src ==# l:src
        let l:op.src = l:tmp
      endif
    endfor
  endwhile
  return l:failures
endfunction

function! diredit#apply() abort
  if !exists('b:diredit_dir')
    return
  endif
  let l:plan = s:plan()
  if !empty(l:plan.errors)
    call s:error('diredit: nothing applied, fix these first:')
    for l:e in l:plan.errors
      call s:error('  ' . l:e)
    endfor
    return
  endif
  if empty(l:plan.ops)
    setlocal nomodified
    echomsg 'diredit: no changes'
    return
  endif

  if g:diredit_confirm
    let l:msg = join(map(copy(l:plan.ops), 's:describe(v:val)'), "\n")
    if confirm(l:msg . "\n\nApply " . len(l:plan.ops) . ' change(s)?', "&Yes\n&No", 2) != 1
      echomsg 'diredit: cancelled'
      return
    endif
  endif

  let l:failures = []
  let l:counts = {'delete': 0, 'move': 0, 'copy': 0, 'create': 0}
  for l:op in filter(copy(l:plan.ops), 'v:val.op ==# "delete"')
    let l:err = s:execute(l:op)
    if empty(l:err)
      let l:counts.delete += 1
    else
      call add(l:failures, s:describe(l:op) . ': ' . l:err)
    endif
  endfor
  let l:transfers = filter(copy(l:plan.ops), 'v:val.op ==# "move" || v:val.op ==# "copy"')
  let l:tfail = s:execute_transfers(l:transfers)
  call extend(l:failures, l:tfail)
  for l:op in l:transfers
    let l:counts[l:op.op] += 1
  endfor
  let l:counts.move -= len(filter(copy(l:tfail), 'v:val =~# "^MOVE"'))
  let l:counts.copy -= len(filter(copy(l:tfail), 'v:val =~# "^COPY"'))
  for l:op in filter(copy(l:plan.ops), 'v:val.op ==# "create"')
    let l:err = s:execute(l:op)
    if empty(l:err)
      let l:counts.create += 1
    else
      call add(l:failures, s:describe(l:op) . ': ' . l:err)
    endif
  endfor

  call diredit#render()
  let l:done = []
  for [l:k, l:word] in [['create', 'created'], ['move', 'moved'], ['copy', 'copied'], ['delete', 'deleted']]
    if l:counts[l:k] > 0
      call add(l:done, l:counts[l:k] . ' ' . l:word)
    endif
  endfor
  if !empty(l:failures)
    call s:error('diredit: ' . len(l:failures) . ' change(s) failed'
      \ . (empty(l:done) ? '' : ' (' . join(l:done, ', ') . ' ok)'))
    for l:f in l:failures
      call s:error('  ' . l:f)
    endfor
  else
    echomsg 'diredit: ' . join(l:done, ', ')
  endif
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction
