" geospell: a geophysics spelling dictionary built from tracked word lists.
"
"   spell/geophysics/words.txt    the vocabulary, one word per line (tracked)
"   spell/geophysics/reject.txt   words never to include (tracked)
"   spell/geophysics/corpus/      text to mine for candidates (not tracked)
"   spell/geophysics.utf-8.spl    the compiled dictionary (generated)
"
" See :help geospell.

let s:root = expand('<sfile>:p:h:h')
let s:dir = s:root . '/spell/geophysics'
let s:words_file = s:dir . '/words.txt'
let s:reject_file = s:dir . '/reject.txt'
let s:spl_base = s:root . '/spell/geophysics'
let s:spl_file = s:spl_base . '.utf-8.spl'

" ------------------------------------------------------------------ lists

" Words from a list file: one per line, blank lines and # comments ignored.
function! s:read_list(file) abort
  if !filereadable(a:file)
    return []
  endif
  let l:out = []
  for l:line in readfile(a:file)
    let l:w = trim(substitute(l:line, '\s*#.*$', '', ''))
    if !empty(l:w)
      call add(l:out, l:w)
    endif
  endfor
  return l:out
endfunction

" Write a list file: keep the leading comment block, then sorted unique words.
function! s:write_list(file, words) abort
  let l:header = []
  if filereadable(a:file)
    for l:line in readfile(a:file)
      if l:line =~# '^\s*#' || l:line =~# '^\s*$'
        call add(l:header, l:line)
      else
        break
      endif
    endfor
  endif
  let l:seen = {}
  let l:out = []
  for l:w in a:words
    if !has_key(l:seen, l:w)
      let l:seen[l:w] = 1
      call add(l:out, l:w)
    endif
  endfor
  call sort(l:out, 'i')
  if !isdirectory(fnamemodify(a:file, ':h'))
    call mkdir(fnamemodify(a:file, ':h'), 'p')
  endif
  call writefile(l:header + l:out, a:file)
endfunction

function! geospell#words() abort
  return s:read_list(s:words_file)
endfunction

" ------------------------------------------------------------------ build

" Compile words.txt minus reject.txt into the .spl with :mkspell.
function! geospell#build(...) abort
  let l:quiet = a:0 && a:1
  let l:reject = {}
  for l:w in s:read_list(s:reject_file)
    let l:reject[l:w] = 1
  endfor
  let l:words = filter(geospell#words(), '!has_key(l:reject, v:val)')
  if empty(l:words)
    if !l:quiet
      echohl WarningMsg | echomsg 'geospell: no words in ' . s:words_file | echohl None
    endif
    return 0
  endif
  let l:tmp = tempname()
  call mkdir(l:tmp, 'p')
  call writefile(['SET UTF-8'], l:tmp . '/geophysics.aff')
  call writefile([len(l:words)] + l:words, l:tmp . '/geophysics.dic')
  try
    execute 'silent mkspell!' fnameescape(s:spl_base) fnameescape(l:tmp . '/geophysics')
  catch
    echohl ErrorMsg | echomsg 'geospell: mkspell failed: ' . v:exception | echohl None
    return 0
  finally
    call delete(l:tmp, 'rf')
  endtry
  " Make windows that use the dictionary pick up the new file.
  for l:w in range(1, winnr('$'))
    if getwinvar(l:w, '&spelllang') =~# 'geophysics'
      call setwinvar(l:w, '&spelllang', getwinvar(l:w, '&spelllang'))
    endif
  endfor
  if !l:quiet
    echomsg printf('geospell: %d words -> %s', len(l:words), fnamemodify(s:spl_file, ':~'))
  endif
  return 1
endfunction

" Build at startup when the .spl is missing or older than the lists.
function! geospell#build_if_stale() abort
  let l:newest = max([getftime(s:words_file), getftime(s:reject_file)])
  if l:newest > 0 && (!filereadable(s:spl_file) || getftime(s:spl_file) < l:newest)
    call geospell#build(1)
  endif
endfunction

" ------------------------------------------------------------ add / remove

" Add a list of words (any length). Words are taken off reject.txt.
function! geospell#add_list(new) abort
  let l:new = filter(copy(a:new), '!empty(v:val)')
  if empty(l:new)
    return
  endif
  let l:set = {}
  for l:w in l:new | let l:set[l:w] = 1 | endfor
  let l:reject = filter(s:read_list(s:reject_file), '!has_key(l:set, v:val)')
  call s:write_list(s:reject_file, l:reject)
  call s:write_list(s:words_file, geospell#words() + l:new)
  call geospell#build(1)
  echomsg 'geospell: added ' . (len(l:new) > 8 ? len(l:new) . ' words' : join(l:new, ', '))
endfunction

" Remove a list of words and keep them out via reject.txt.
function! geospell#remove_list(gone) abort
  let l:gone = filter(copy(a:gone), '!empty(v:val)')
  if empty(l:gone)
    return
  endif
  let l:set = {}
  for l:w in l:gone | let l:set[l:w] = 1 | endfor
  call s:write_list(s:words_file, filter(geospell#words(), '!has_key(l:set, v:val)'))
  call s:write_list(s:reject_file, s:read_list(s:reject_file) + l:gone)
  call geospell#build(1)
  echomsg 'geospell: removed ' . join(l:gone, ', ') . ' (kept out by reject.txt)'
endfunction

" Command forms: a few words as arguments, or the word under the cursor.
function! geospell#add(...) abort
  call geospell#add_list(empty(a:000) ? [expand('<cword>')] : a:000)
endfunction

function! geospell#remove(...) abort
  call geospell#remove_list(empty(a:000) ? [expand('<cword>')] : a:000)
endfunction

" --------------------------------------------------------------- harvest

" Turn one line of source text into candidate tokens.
function! s:tokens(line) abort
  let l:s = a:line
  " Markup that is never vocabulary.
  let l:s = substitute(l:s, 'https\?://\S\+', ' ', 'g')
  " LaTeX: \begin{env}, \cite{key}, \includegraphics[opts]{file} and the
  " like carry identifiers, not vocabulary; then any remaining \command.
  let l:s = substitute(l:s, '\\\%(begin\|end\|usepackage\|label\|ref\|eqref\|cite\w*\|includegraphics\|input\|include\|bibliography\w*\|documentclass\|newcommand\|renewcommand\|url\|href\)\*\=\%(\[[^]]*\]\)\=\%({[^}]*}\)\{1,2}', ' ', 'g')
  let l:s = substitute(l:s, '\\[A-Za-z@]\+\*\=', ' ', 'g')
  " Typst: #calls, key: value options, and name( calls in code blocks.
  let l:s = substitute(l:s, '#[A-Za-z_][A-Za-z0-9_.-]*', ' ', 'g')
  let l:s = substitute(l:s, '\<[A-Za-z_][A-Za-z0-9_.-]*\ze\s*[=(]', ' ', 'g')
  let l:s = substitute(l:s, '\<[a-z][a-z0-9_-]*\ze\s*:\s*\S', ' ', 'g')
  " Typst <labels> and cite keys.
  let l:s = substitute(l:s, '<[A-Za-z][A-Za-z0-9_:.-]*>', ' ', 'g')
  " BibTeX entry keys (@article{key,), @citekeys, and DOIs.
  let l:s = substitute(l:s, '@[A-Za-z]\+\s*{[^,]*,', ' ', 'g')
  let l:s = substitute(l:s, '@[A-Za-z][A-Za-z0-9_:.-]*', ' ', 'g')
  let l:s = substitute(l:s, '\<10\.\d\{4,}/\S\+', ' ', 'g')
  let l:out = []
  " Latin letters only (ASCII plus Latin-1 accents): Cyrillic or Greek
  " tokens are never en_us vocabulary.
  for l:t in split(l:s, "[^[:alpha:]']\\+")
    let l:t = substitute(l:t, "^'\\+\\|'\\+$", '', 'g')
    if len(l:t) < 3 || len(l:t) > 30 || l:t !~# '^[A-Za-zÀ-ÖØ-öø-ÿ]\+$'
      continue
    endif
    " Short lowercase tokens are hyphenation fragments (ing, ies) far more
    " often than words; acronyms keep their capitals and survive.
    if len(l:t) <= 3 && l:t =~# '^[a-z]\+$'
      continue
    endif
    if l:t =~# '\(.\)\1\1'      " three identical letters in a row: junk
      continue
    endif
    call add(l:out, l:t)
  endfor
  return l:out
endfunction

" Files under a path argument: a file, a glob, or a directory (recursive).
function! s:expand_source(arg) abort
  let l:p = expand(a:arg)
  if isdirectory(l:p)
    return glob(l:p . '/**/*.{tex,typ,md,txt,bib,rst,org}', 1, 1)
  endif
  return glob(l:p, 1, 1)
endfunction

" Scan sources for words the base language does not know. Returns a dict
" word -> count, ignoring words already in words.txt or reject.txt.
function! geospell#candidates(sources) abort
  let l:known = {}
  for l:w in geospell#words() + s:read_list(s:reject_file)
    let l:known[l:w] = 1
  endfor
  let l:files = []
  for l:src in a:sources
    call extend(l:files, s:expand_source(l:src))
  endfor
  " Data files with a text extension can be enormous; skip anything over
  " the limit rather than spend minutes on numbers.
  let l:limit = get(g:, 'geospell_max_file_size', 3 * 1024 * 1024)
  let l:skipped = filter(copy(l:files), 'getfsize(v:val) > l:limit')
  call filter(l:files, 'getfsize(v:val) <= l:limit')
  if !empty(l:skipped)
    echomsg 'geospell: skipped ' . len(l:skipped) . ' file(s) larger than '
      \ . (l:limit / 1024) . ' KiB (g:geospell_max_file_size)'
  endif
  if empty(l:files)
    echohl WarningMsg | echomsg 'geospell: no files found in ' . string(a:sources) | echohl None
    return {}
  endif
  " spellbadword() judges by the current buffer, so use a scratch one with
  " only the base language.
  let l:save = [bufnr('%'), winsaveview()]
  keepalt keepjumps new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal spell spelllang=en_us
  let l:counts = {}
  let l:verdict = {}
  try
    for l:file in l:files
      for l:line in readfile(l:file)
        for l:t in s:tokens(l:line)
          if has_key(l:known, l:t)
            continue
          endif
          if !has_key(l:verdict, l:t)
            let l:verdict[l:t] = spellbadword(l:t)[1] ==# 'bad'
          endif
          if l:verdict[l:t]
            let l:counts[l:t] = get(l:counts, l:t, 0) + 1
          endif
        endfor
      endfor
    endfor
  finally
    close
    execute 'keepalt buffer' l:save[0]
    call winrestview(l:save[1])
  endtry
  return l:counts
endfunction

" Show candidates in a buffer: one "count<Tab>word" per line, most frequent
" first. Delete the lines you do not want, then :GeoSpellAccept.
function! geospell#harvest(min_count, ...) abort
  let l:sources = a:0 ? a:000 : get(g:, 'geospell_sources', [s:dir . '/corpus'])
  let l:counts = geospell#candidates(l:sources)
  let l:items = filter(items(l:counts), 'v:val[1] >= a:min_count')
  call sort(l:items, {a, b -> b[1] == a[1] ? (a[0] <# b[0] ? -1 : 1) : b[1] - a[1]})
  let l:lines = [
    \ '# geospell candidates: ' . len(l:items) . ' words not in en_us, from ' . join(l:sources, ' '),
    \ '# Delete the lines you do not want (dd, :g/pattern/d, ...), then run',
    \ '# :GeoSpellAccept to add the rest to words.txt and rebuild.',
    \ '# Lines starting with # are ignored. Format: count<Tab>word',
    \ ]
  for [l:w, l:n] in l:items
    call add(l:lines, l:n . "\t" . l:w)
  endfor
  keepalt keepjumps new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  call setline(1, l:lines)
  setlocal nomodified filetype=geospell
  let b:geospell_candidates = 1
  echomsg 'geospell: ' . len(l:items) . ' candidates; delete unwanted lines, then :GeoSpellAccept'
endfunction

function! geospell#accept() abort
  if !get(b:, 'geospell_candidates', 0)
    echohl ErrorMsg | echomsg 'geospell: run this in a :GeoSpellHarvest buffer' | echohl None
    return
  endif
  let l:new = []
  for l:line in getline(1, '$')
    if l:line =~# '^\s*#' || l:line =~# '^\s*$'
      continue
    endif
    let l:w = matchstr(l:line, '^\d*\s*\zs\S\+')
    if !empty(l:w)
      call add(l:new, l:w)
    endif
  endfor
  close
  call geospell#add_list(l:new)
  echomsg printf('geospell: accepted %d words; %d in words.txt', len(l:new), len(geospell#words()))
endfunction

function! geospell#stats() abort
  echo printf('geospell: %d words, %d rejected, dictionary %s',
    \ len(geospell#words()), len(s:read_list(s:reject_file)),
    \ filereadable(s:spl_file) ? 'built ' . strftime('%Y-%m-%d %H:%M', getftime(s:spl_file)) : 'NOT BUILT')
endfunction
