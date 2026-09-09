" See plugin/tagsgen.vim for the pattern tables and the :MakeTags command.

function! s:slash(path) abort
  return substitute(a:path, '\\', '/', 'g')
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

function! tagsgen#make(dir) abort
  let l:root = s:slash(fnamemodify(empty(a:dir) ? getcwd() : a:dir, ':p'))
  let l:root = substitute(l:root, '/$', '', '')
  if !isdirectory(l:root)
    echohl ErrorMsg | echomsg 'MakeTags: not a directory: ' . l:root | echohl None
    return
  endif
  let l:start = reltime()
  let l:files = s:files(l:root)
  let l:tags = []
  let l:prefix = len(l:root) + 1
  let l:done = 0
  let l:shown = 0.0
  for [l:path, l:ft] in l:files
    call extend(l:tags, s:scan(l:path, strpart(l:path, l:prefix), l:ft))
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
  let l:out = l:root . '/tags'
  if writefile(l:header + l:tags, l:out) != 0
    echohl ErrorMsg | echomsg 'MakeTags: could not write ' . l:out | echohl None
    return
  endif
  echomsg printf('MakeTags: %d tags from %d files in %.2fs -> %s',
    \ len(l:tags), len(l:files), reltimefloat(reltime(l:start)), fnamemodify(l:out, ':~'))
endfunction
