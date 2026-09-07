" See plugin/tagsgen.vim for the pattern tables and the :MakeTags command.

function! s:slash(path) abort
  return substitute(a:path, '\\', '/', 'g')
endfunction

" Files under root worth scanning: [path, filetype] pairs.
function! s:files(root) abort
  let l:exclude = '\V/\%(' . join(map(copy(g:tagsgen_exclude), 'escape(v:val, "\\")'), '\|') . '\)/'
  let l:out = []
  for l:path in glob(a:root . '/**/*', 1, 1)
    let l:p = s:slash(l:path)
    if isdirectory(l:p) || (l:p . '/') =~# l:exclude
      continue
    endif
    let l:ft = get(g:tagsgen_filetypes, tolower(fnamemodify(l:p, ':e')), '')
    if !empty(l:ft) && has_key(g:tagsgen_patterns, l:ft) && getfsize(l:p) <= g:tagsgen_max_size
      call add(l:out, [l:p, l:ft])
    endif
  endfor
  return l:out
endfunction

" The tag search command for a line: /^text$/ with \ and / escaped and tabs
" written as \t (the file is tab separated). Tag patterns are matched with
" 'nomagic', where \t still means a tab and nothing else is special.
function! s:address(line) abort
  return '/^' . substitute(escape(a:line, '\/'), "\t", '\\t', 'g') . '$/;"'
endfunction

" Patterns for a filetype with the skip rule folded in as a negative
" lookahead after the ^ anchor, so one regex call decides everything.
function! s:compiled(ft) abort
  let l:skip = get(g:tagsgen_skip, a:ft, '')
  let l:out = []
  for l:entry in g:tagsgen_patterns[a:ft]
    let l:pat = l:entry[0]
    if !empty(l:skip) && l:pat =~# '^\^'
      let l:pat = '^\%(' . substitute(l:skip, '^\^', '', '') . '\)\@!' . l:pat[1:]
    endif
    call add(l:out, [l:pat, l:entry[1]])
  endfor
  return l:out
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
  let l:taken = {}
  for [l:pat, l:kind] in s:compiled(a:ft)
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
  for [l:path, l:ft] in l:files
    call extend(l:tags, s:scan(l:path, strpart(l:path, l:prefix), l:ft))
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
