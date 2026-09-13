" See plugin/tagsgen.vim for the pattern tables and the :MakeTags command.

function! s:slash(path) abort
  return substitute(a:path, '\\', '/', 'g')
endfunction

" A directory as an absolute, forward-slashed path with no trailing slash.
function! s:dir(path) abort
  return substitute(s:slash(fnamemodify(a:path, ':p')), '/$', '', '')
endfunction

" A file name as written in a tags file that lives in directory base:
" relative to base, which is how Vim reads it ('tagrelative'), climbing out
" with ../ where the file is not below it. Absolute when the two share
" nothing, as for a file on another drive.
function! s:relative(path, base) abort
  let l:p = split(a:path, '/', 1)
  let l:b = split(a:base, '/', 1)
  let l:n = 0
  while l:n < len(l:p) - 1 && l:n < len(l:b)
    \ && (has('win32') ? l:p[l:n] ==? l:b[l:n] : l:p[l:n] ==# l:b[l:n])
    let l:n += 1
  endwhile
  if l:n == 0
    return a:path
  endif
  return repeat('../', len(l:b) - l:n) . join(l:p[l:n :], '/')
endfunction

" Files under root worth scanning: [path, filetype] pairs.
"
" A readdirex() walk, not glob('**'): glob has to descend into node_modules
" and .git before the exclude list can be applied to what it found, and on
" a tree with a large node_modules that alone took twice as long as the
" scan. readdirex() also hands over each entry's type and size, so nothing
" is stat'ed twice. Symbolic links and junctions are not followed.
function! s:files(root) abort
  let l:out = []
  let l:todo = [a:root]
  while !empty(l:todo)
    let l:dir = remove(l:todo, -1)
    try
      let l:entries = readdirex(l:dir)
    catch
      continue
    endtry
    for l:e in l:entries
      if l:e.type ==# 'dir'
        if index(g:tagsgen_exclude, l:e.name) < 0
          call add(l:todo, l:dir . '/' . l:e.name)
        endif
      elseif l:e.type ==# 'file'
        let l:ft = get(g:tagsgen_filetypes, tolower(fnamemodify(l:e.name, ':e')), '')
        if !empty(l:ft) && has_key(g:tagsgen_patterns, l:ft) && l:e.size <= g:tagsgen_max_size
          call add(l:out, [l:dir . '/' . l:e.name, l:ft])
        endif
      endif
    endfor
  endwhile
  return l:out
endfunction

" The tag search command for a line: /^text$/ with \ and / escaped and tabs
" written as \t (the file is tab separated). Tag patterns are matched with
" 'nomagic', where \t still means a tab and nothing else is special.
function! s:address(line) abort
  return '/^' . substitute(escape(a:line, '\/'), "\t", '\\t', 'g') . '$/;"'
endfunction

" Tag lines for one file. "rel" is the path as written in the tags file.
" Each pattern runs over all lines in one C-speed matchstrlist() call; the
" first pattern (in table order) to match a line owns that line.
function! s:scan(path, rel, ft) abort
  let l:tags = []
  try
    let l:lines = readfile(a:path)
  catch
    return l:tags
  endtry
  call map(l:lines, 'v:val =~# "\r$" ? v:val[:-2] : v:val')
  " Lines the skip rule covers (comments) are blanked before the patterns
  " run. Folding the rule into each pattern as a lookahead instead made the
  " C function pattern five times slower.
  let l:skip = get(g:tagsgen_skip, a:ft, '')
  if !empty(l:skip)
    for l:m in matchstrlist(l:lines, l:skip)
      let l:lines[l:m.idx] = ''
    endfor
  endif
  let l:taken = {}
  for l:entry in g:tagsgen_patterns[a:ft]
    let [l:pat, l:kind] = l:entry[0:1]
    for l:m in matchstrlist(l:lines, l:pat)
      if has_key(l:taken, l:m.idx) || empty(l:m.text)
        continue
      endif
      let l:taken[l:m.idx] = 1
      call add(l:tags, l:m.text . "\t" . a:rel . "\t" . s:address(l:lines[l:m.idx])
        \ . "\t" . l:kind . "\tline:" . (l:m.idx + 1))
    endfor
  endfor
  return l:tags
endfunction

" :MakeTags [dir] [into]: scan dir, write into/tags. into defaults to dir,
" so a tags file can sit in one directory and describe another.
function! tagsgen#make(...) abort
  if a:0 > 2
    echohl ErrorMsg | echomsg 'MakeTags: expected [dir] [into]' | echohl None
    return
  endif
  let l:root = s:dir(a:0 > 0 && !empty(a:1) ? a:1 : getcwd())
  let l:into = a:0 > 1 ? s:dir(a:2) : l:root
  for l:d in [l:root, l:into]
    if !isdirectory(l:d)
      echohl ErrorMsg | echomsg 'MakeTags: not a directory: ' . l:d | echohl None
      return
    endif
  endfor
  let l:start = reltime()
  let l:files = s:files(l:root)
  let l:tags = []
  let l:done = 0
  let l:shown = 0.0
  for [l:path, l:ft] in l:files
    call extend(l:tags, s:scan(l:path, s:relative(l:path, l:into), l:ft))
    let l:done += 1
    " A scan that runs long says how far it is, once a second. A quick one
    " says nothing until the summary.
    let l:elapsed = reltimefloat(reltime(l:start))
    if l:elapsed - l:shown >= 1.0
      let l:shown = l:elapsed
      redraw
      echo printf('MakeTags: %d of %d files, %d tags so far ...', l:done, len(l:files), len(l:tags))
    endif
  endfor
  " Sorted by byte value, which is what !_TAG_FILE_SORTED 1 promises and
  " what Vim's binary search expects.
  call sort(l:tags)
  let l:header = [
    \ "!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;\" to lines/",
    \ "!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/",
    \ "!_TAG_PROGRAM_NAME\ttagsgen.vim\t//",
    \ ]
  let l:out = l:into . '/tags'
  if writefile(l:header + l:tags, l:out) != 0
    echohl ErrorMsg | echomsg 'MakeTags: could not write ' . l:out | echohl None
    return
  endif
  echomsg printf('MakeTags: %d tags from %d files in %.2fs -> %s',
    \ len(l:tags), len(l:files), reltimefloat(reltime(l:start)), fnamemodify(l:out, ':~'))
endfunction
