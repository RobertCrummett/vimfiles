" gq for markdown tables. Set as 'formatexpr' by after/ftplugin/markdown.vim.
"
" A table is a run of lines with a pipe in them that includes a separator
" row (|---|:--:|). Its cells are trimmed and padded to the widest cell in
" each column, the separator row is redrawn to the same widths keeping its
" alignment colons, and every row gets a leading and trailing pipe, so the
" bars line up and the rules are as long as the rows. Nothing in a table is
" ever wrapped. Lines that are not part of a table are formatted by Vim's
" own gq, so a gqip over prose behaves as it always did, and a range that
" mixes the two gets each part its own treatment.

" A row of a table: contains a pipe that is not escaped.
function! s:is_row(line) abort
  return a:line =~# '\\\@<!|'
endfunction

" The separator row under the header: |---|:--:|, pipes optional at the edges.
function! s:is_separator(line) abort
  return a:line =~# '^\s*|\?\s*:\?-\+:\?\s*\%(|\s*:\?-\+:\?\s*\)*|\?\s*$'
endfunction

" Cells of a row, trimmed, without the edge pipes.
function! s:cells(line) abort
  let l:s = substitute(a:line, '^\s*|', '', '')
  let l:s = substitute(l:s, '|\s*$', '', '')
  return map(split(l:s, '\\\@<!|', 1), 'trim(v:val)')
endfunction

" Alignment of one separator cell: l (---), L (:--, left said
" explicitly, kept as written), r (--:) or c (:-:).
function! s:align(cell) abort
  if a:cell =~# '^:-*:$'
    return 'c'
  elseif a:cell =~# '-:$'
    return 'r'
  elseif a:cell =~# '^:'
    return 'L'
  endif
  return 'l'
endfunction

" The separator cell for an alignment at a width.
function! s:rule(align, width) abort
  return (a:align =~# '[Lc]' ? ':' : '-') . repeat('-', a:width - 2) . (a:align =~# '[rc]' ? ':' : '-')
endfunction

function! s:pad(text, width, align) abort
  let l:room = a:width - strdisplaywidth(a:text)
  if a:align ==# 'r'
    return repeat(' ', l:room) . a:text
  elseif a:align ==# 'c'
    return repeat(' ', l:room / 2) . a:text . repeat(' ', l:room - l:room / 2)
  endif
  return a:text . repeat(' ', l:room)
endfunction

" Rewrite lines first..last, a table, in place.
function! markdown#format_table(first, last) abort
  let l:lines = getline(a:first, a:last)
  let l:indent = matchstr(l:lines[0], '^\s*')
  let l:rows = []
  let l:seps = {}
  for l:i in range(len(l:lines))
    call add(l:rows, s:cells(l:lines[l:i]))
    if s:is_separator(l:lines[l:i])
      let l:seps[l:i] = 1
    endif
  endfor
  let l:ncol = max(map(copy(l:rows), 'len(v:val)'))
  " Alignment per column from the first separator row; left otherwise.
  let l:aligns = repeat(['l'], l:ncol)
  for l:i in sort(map(keys(l:seps), 'str2nr(v:val)'), 'n')
    let l:aligns = map(range(l:ncol), 'v:val < len(l:rows[l:i]) ? s:align(l:rows[l:i][v:val]) : "l"')
    break
  endfor
  " Column widths: the widest cell, and never less than the three
  " characters a separator cell needs.
  let l:widths = repeat([3], l:ncol)
  for l:i in range(len(l:rows))
    if has_key(l:seps, l:i)
      continue
    endif
    for l:c in range(len(l:rows[l:i]))
      let l:widths[l:c] = max([l:widths[l:c], strdisplaywidth(l:rows[l:i][l:c])])
    endfor
  endfor
  let l:out = []
  for l:i in range(len(l:rows))
    let l:cells = []
    for l:c in range(l:ncol)
      if has_key(l:seps, l:i)
        let l:cell = s:rule(l:aligns[l:c], l:widths[l:c])
      else
        let l:cell = s:pad(get(l:rows[l:i], l:c, ''), l:widths[l:c], l:aligns[l:c])
      endif
      call add(l:cells, l:cell)
    endfor
    call add(l:out, l:indent . '| ' . join(l:cells, ' | ') . ' |')
  endfor
  call setline(a:first, l:out)
endfunction

" The table around line lnum: [first, last] of the contiguous run of rows
" that holds a separator, or [] when the line is not in a table.
function! s:table_at(lnum) abort
  if !s:is_row(getline(a:lnum))
    return []
  endif
  let l:first = a:lnum
  while l:first > 1 && s:is_row(getline(l:first - 1))
    let l:first -= 1
  endwhile
  let l:last = a:lnum
  while l:last < line('$') && s:is_row(getline(l:last + 1))
    let l:last += 1
  endwhile
  for l:l in range(l:first, l:last)
    if s:is_separator(getline(l:l))
      return [l:first, l:last]
    endif
  endfor
  return []
endfunction

" 'formatexpr'. Returns 1 to hand the range back to Vim.
function! markdown#format() abort
  " Automatic wrapping while typing (v:char is the typed character) is
  " Vim's business.
  if !empty(v:char)
    return 1
  endif
  let l:first = v:lnum
  let l:last = v:lnum + v:count - 1
  " Cut the range into table blocks and the rest. A table is taken whole
  " even when the range covers only part of it: the column widths are a
  " property of the whole table.
  let l:blocks = []
  let l:l = l:first
  while l:l <= l:last
    let l:t = s:table_at(l:l)
    if empty(l:t)
      if !empty(l:blocks) && !l:blocks[-1][2] && l:blocks[-1][1] == l:l - 1
        let l:blocks[-1][1] = l:l
      else
        call add(l:blocks, [l:l, l:l, 0])
      endif
      let l:l += 1
    else
      call add(l:blocks, [l:t[0], l:t[1], 1])
      let l:l = l:t[1] + 1
    endif
  endwhile
  if empty(filter(copy(l:blocks), 'v:val[2]'))
    return 1
  endif
  " Bottom up, so a block changing its line count leaves the ones above
  " it where they were. Prose goes through Vim's own gq with this
  " function out of the way.
  let l:view = winsaveview()
  for [l:s, l:e, l:table] in reverse(l:blocks)
    if l:table
      call markdown#format_table(l:s, l:e)
    else
      let l:save = &l:formatexpr
      setlocal formatexpr=
      try
        execute 'silent normal! ' . l:s . 'GV' . l:e . 'Ggq'
      finally
        let &l:formatexpr = l:save
      endtry
    endif
  endfor
  call winrestview(l:view)
  return 0
endfunction
