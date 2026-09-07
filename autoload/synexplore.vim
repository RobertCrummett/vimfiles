" ------------------------------------------------------------ sources

function! s:slash(path) abort
  return substitute(a:path, '\\', '/', 'g')
endfunction

" Classify where something was set. Returns [label, editable].
function! s:classify(path) abort
  if empty(a:path)
    return ['Vim built-in default', 0]
  endif
  let l:p = s:slash(fnamemodify(a:path, ':p'))
  let l:rt = s:slash(fnamemodify($VIMRUNTIME, ':p'))
  let l:vf = s:slash(fnamemodify(split(&runtimepath, ',')[0], ':p'))
  if l:p =~# '\V\^' . escape(l:rt, '\')
    return ['system runtime, not editable: override it from vimfiles', 0]
  elseif l:p =~# '\V\^' . escape(l:vf, '\') . 'colors/'
    return ['your colorscheme, editable', 1]
  elseif l:p =~# '\V\^' . escape(l:vf, '\') . 'pack/'
    return ['a plugin package under vimfiles', 1]
  elseif l:p =~# '\V\^' . escape(l:vf, '\')
    return ['your vimfiles, editable', 1]
  elseif l:p =~# 'vimrc$'
    return ['your vimrc, editable', 1]
  endif
  return ['elsewhere', 0]
endfunction

" 'Last set from X line N' out of :verbose output -> [file, line] or ['', 0].
function! s:last_set(text) abort
  let l:m = matchlist(a:text, 'Last set from \(.\{-}\) line \(\d\+\)')
  return empty(l:m) ? ['', 0] : [l:m[1], str2nr(l:m[2])]
endfunction

function! s:source_line(file, line) abort
  if empty(a:file)
    return 'set by: Vim built-in default'
  endif
  let [l:label, l:editable] = s:classify(a:file)
  return printf('set from: %s line %d  [%s]', fnamemodify(a:file, ':~'), a:line, l:label)
endfunction

" ------------------------------------------------------------- groups

" Attribute summary of one hlget() entry (its own settings, not resolved).
function! s:attrs(d) abort
  let l:parts = []
  for l:k in ['guifg', 'guibg', 'guisp', 'gui', 'ctermfg', 'ctermbg', 'cterm', 'term']
    if has_key(a:d, l:k) && !empty(a:d[l:k])
      call add(l:parts, l:k . '=' . a:d[l:k])
    endif
  endfor
  return join(l:parts, ' ')
endfunction

" Effective colours as the screen shows them.
function! s:effective(name) abort
  let l:id = synIDtrans(hlID(a:name))
  let l:parts = []
  for [l:k, l:what] in [['fg', 'fg#'], ['bg', 'bg#'], ['sp', 'sp#']]
    " GUI colour when there is one, otherwise the terminal colour number.
    let l:v = synIDattr(l:id, l:what)
    if empty(l:v)
      let l:v = synIDattr(l:id, l:k)
    endif
    if !empty(l:v)
      call add(l:parts, l:k . '=' . l:v)
    endif
  endfor
  let l:flags = filter(['bold', 'italic', 'underline', 'undercurl', 'reverse', 'strike'],
    \ 'synIDattr(l:id, v:val) == 1')
  if !empty(l:flags)
    call add(l:parts, join(l:flags, ','))
  endif
  if empty(l:parts)
    " No colours are active (e.g. no GUI and no terminal colours): report
    " what the resolved group declares instead.
    let l:h = hlget(synIDattr(l:id, 'name'))
    let l:declared = empty(l:h) ? '' : s:attrs(l:h[0])
    return empty(l:declared) ? 'plain (Normal)' : 'declared ' . l:declared
  endif
  return join(l:parts, ' ')
endfunction

" Follow links from a group. Returns a list of names, first is the group.
function! s:chain(name) abort
  let l:chain = [a:name]
  let l:cur = a:name
  while len(l:chain) < 20
    let l:h = hlget(l:cur)
    if empty(l:h) || !has_key(l:h[0], 'linksto') || empty(l:h[0].linksto)
      break
    endif
    let l:cur = l:h[0].linksto
    call add(l:chain, l:cur)
  endwhile
  return l:chain
endfunction

" Lines describing a group: chain, attributes, and where each hop was set.
function! s:group_lines(name, indent) abort
  let l:i = a:indent
  let l:h = hlget(a:name)
  if empty(l:h)
    return [l:i . a:name . ': no such highlight group']
  endif
  let l:lines = []
  let l:chain = s:chain(a:name)
  call add(l:lines, l:i . 'link chain: ' . join(l:chain, ' -> '))
  for l:g in l:chain
    let l:d = hlget(l:g)[0]
    let l:desc = has_key(l:d, 'linksto') && !empty(l:d.linksto)
      \ ? 'links to ' . l:d.linksto : (get(l:d, 'cleared', 0) ? 'cleared' : s:attrs(l:d))
    if has_key(l:d, 'linksto') && !empty(l:d.linksto) && !empty(s:attrs(l:d))
      let l:desc .= ' (also has own attributes: ' . s:attrs(l:d) . ')'
    endif
    let [l:file, l:lnum] = s:last_set(execute('verbose highlight ' . l:g, 'silent!'))
    call add(l:lines, printf('%s  %-24s %s', l:i, l:g, l:desc))
    call add(l:lines, l:i . '      ' . s:source_line(l:file, l:lnum))
  endfor
  call add(l:lines, l:i . 'on screen: ' . s:effective(a:name))
  return l:lines
endfunction

function! synexplore#group(name) abort
  let l:lines = ['Highlight group ' . a:name, '']
  call extend(l:lines, s:group_lines(a:name, ''))
  call s:scratch('SynGroup ' . a:name, l:lines, 0)
endfunction

" ----------------------------------------------------------- rule text

" Syntax files that can define rules for this buffer: the files for
" 'syntax' on the runtimepath, their after/ counterparts, and files they
" pull in with :runtime or :syntax include (cpp sources c, for example).
function! s:syntax_files() abort
  let l:todo = [&syntax]
  let l:seen = {}
  let l:files = []
  while !empty(l:todo)
    let l:n = remove(l:todo, 0)
    if empty(l:n) || has_key(l:seen, l:n)
      continue
    endif
    let l:seen[l:n] = 1
    for l:f in globpath(&runtimepath, 'syntax/' . l:n . '.vim', 0, 1)
          \ + globpath(&runtimepath, 'after/syntax/' . l:n . '.vim', 0, 1)
      " ~/vimfiles/after is on the runtimepath too, so dedupe by path.
      let l:key = tolower(s:slash(fnamemodify(l:f, ':p')))
      if has_key(l:seen, l:key)
        continue
      endif
      let l:seen[l:key] = 1
      call add(l:files, l:f)
      for l:line in readfile(l:f)
        let l:inc = matchstr(l:line, '\c^\s*ru\%[ntime]!\=\s\+syntax/\zs[A-Za-z0-9_]\+\ze\.vim')
        if empty(l:inc)
          let l:inc = matchstr(l:line, '\csyntax/\zs[A-Za-z0-9_]\+\ze\.vim')
          if l:line !~# '\<sy\%[ntax]\s\+include\>'
            let l:inc = ''
          endif
        endif
        if !empty(l:inc)
          call add(l:todo, l:inc)
        endif
      endfor
    endfor
  endwhile
  return l:files
endfunction

" Vim does not remember where a syntax rule came from (only highlight
" groups get "Last set from"), so look for the defining lines ourselves.
function! s:rule_sources(group) abort
  let l:hits = []
  let l:def = '\<sy\%[ntax]\s\+\%(keyword\|match\|region\|cluster\)\s\+' . a:group . '\>'
  let l:mg = '\<matchgroup=' . a:group . '\>'
  for l:f in s:syntax_files()
    let l:lnum = 0
    for l:line in readfile(l:f)
      let l:lnum += 1
      if l:line =~# l:def || l:line =~# l:mg
        call add(l:hits, [l:f, l:lnum])
      endif
    endfor
  endfor
  return l:hits
endfunction

" The ':syntax list' entries for one group, then the file and line of
" each rule that defines it. Returns a list of lines.
function! s:rule_lines(group, indent) abort
  let l:out = execute('syntax list ' . a:group, 'silent!')
  if l:out =~# 'E28\|No Syntax items\|E392'
    return [a:indent . '(no syntax rule of that name in this buffer)']
  endif
  let l:lines = []
  for l:l in split(l:out, "\n")
    if l:l =~# '^--- Syntax items' || l:l =~# '^\s*$'
      continue
    endif
    call add(l:lines, a:indent . '  ' . substitute(l:l, '^\s*', '', ''))
  endfor
  let l:hits = s:rule_sources(a:group)
  if empty(l:hits)
    call add(l:lines, a:indent . '    rule from: not found in the syntax files for "' . &syntax . '" (defined at runtime?)')
  endif
  for [l:file, l:lnum] in l:hits
    call add(l:lines, a:indent . '    ' . substitute(s:source_line(l:file, l:lnum), '^set from', 'rule from', ''))
  endfor
  return l:lines
endfunction

" ------------------------------------------------------------- cursor

function! synexplore#cursor(to_buffer) abort
  let l:lnum = line('.')
  let l:col = col('.')
  let l:char = strpart(getline('.'), l:col - 1, 1)
  let l:lines = []
  call add(l:lines, 'Why the character under the cursor is coloured the way it is.')
  call add(l:lines, 'Move the cursor onto other text and run :SynCursor again for that spot.')
  call add(l:lines, '')
  call add(l:lines, printf('Line %d column %d, character %s, filetype "%s", syntax "%s", colorscheme "%s"',
    \ l:lnum, l:col, empty(l:char) ? '(none)' : '"' . l:char . '"', &filetype, &syntax, get(g:, 'colors_name', '')))

  let l:stack = map(synstack(l:lnum, l:col), 'synIDattr(v:val, "name")')
  let l:shown = synIDattr(synID(l:lnum, l:col, 1), 'name')
  let l:raw = synIDattr(synID(l:lnum, l:col, 0), 'name')
  let l:final = synIDattr(synIDtrans(synID(l:lnum, l:col, 1)), 'name')
  call add(l:lines, '')
  if empty(l:stack)
    call add(l:lines, 'No syntax item here: the text takes the Normal highlight.')
  else
    call add(l:lines, 'Syntax stack, outermost first. The innermost item that is not')
    call add(l:lines, 'transparent supplies the colour; it is marked <== applies.')
    let l:n = 0
    for l:g in l:stack
      let l:n += 1
      let l:mark = l:g ==# l:shown ? '   <== applies' : ''
      call add(l:lines, '')
      call add(l:lines, printf('%d. %s%s', l:n, l:g, l:mark))
      call extend(l:lines, s:rule_lines(l:g, '  '))
      call extend(l:lines, s:group_lines(l:g, '  '))
    endfor
    if !empty(l:raw) && l:raw !=# l:shown
      call add(l:lines, '')
      call add(l:lines, printf('The innermost item %s is transparent, so %s shows through.', l:raw, l:shown))
    endif
  endif
  call add(l:lines, '')
  call add(l:lines, 'Colour on screen comes from: ' . (empty(l:final) ? 'Normal' : l:final) . '  (' . s:effective(empty(l:shown) ? 'Normal' : l:shown) . ')')

  let l:conceal = synconcealed(l:lnum, l:col)
  if !empty(l:conceal) && l:conceal[0]
    call add(l:lines, 'Concealed here' . (empty(l:conceal[1]) ? '' : ', shown as "' . l:conceal[1] . '"'))
  endif
  let l:matches = getmatches()
  if !empty(l:matches)
    call add(l:lines, '')
    call add(l:lines, 'Window matches (:match / matchadd) that can override syntax colours:')
    for l:m in l:matches
      call add(l:lines, printf('  %s priority %d: %s', l:m.group, l:m.priority,
        \ has_key(l:m, 'pattern') ? l:m.pattern : 'positions ' . string(filter(copy(l:m), 'v:key =~# "^pos"'))))
    endfor
  endif

  if a:to_buffer
    call s:scratch('SynCursor', l:lines, 0)
  else
    echo join(l:lines, "\n")
  endif
endfunction

" ------------------------------------------------------- all groups

function! synexplore#highlights(pattern) abort
  " One :verbose highlight call gives every group with its source.
  let l:out = split(execute('verbose highlight', 'silent!'), "\n")
  let l:entries = []
  for l:l in l:out
    if l:l =~# 'Last set from'
      if !empty(l:entries)
        let [l:entries[-1].file, l:entries[-1].line] = s:last_set(l:l)
      endif
      continue
    endif
    let l:name = matchstr(l:l, '^\S\+')
    if empty(l:name)
      continue
    endif
    let l:desc = substitute(l:l, '^\S\+\s\+xxx\s*', '', '')
    call add(l:entries, {'name': l:name, 'desc': l:desc, 'file': '', 'line': 0})
  endfor
  if !empty(a:pattern)
    call filter(l:entries, 'v:val.name =~? a:pattern')
  endif

  let l:lines = [printf('%d highlight groups%s, colorscheme "%s". Sample text is drawn in the group.',
    \ len(l:entries), empty(a:pattern) ? '' : ' matching /' . a:pattern . '/', get(g:, 'colors_name', '')),
    \ 'Columns: group | sample | its own link or attributes | on screen | set from [who owns it]', '']
  let l:samples = []
  for l:e in l:entries
    let l:src = empty(l:e.file) ? 'built-in' : fnamemodify(l:e.file, ':~') . ':' . l:e.line
    let [l:label, l:editable] = s:classify(l:e.file)
    let l:owner = empty(l:e.file) ? 'default' : (l:editable ? 'yours' : (l:label =~# 'runtime' ? 'runtime' : 'other'))
    let l:line = printf('%-32s xxx  %-48s | %s | %s [%s]', l:e.name, l:e.desc, s:effective(l:e.name), l:src, l:owner)
    call add(l:lines, l:line)
    call add(l:samples, [l:e.name, len(l:lines), 34, 3])
  endfor
  call s:scratch('SynHighlights', l:lines, l:samples)
endfunction

" ---------------------------------------------------------- all rules

function! synexplore#rules(group) abort
  let l:lines = [
    \ 'Syntax rules in effect for this buffer (filetype "' . &filetype . '", syntax "' . &syntax . '").',
    \ 'How Vim picks a colour at one position:',
    \ '  - keywords beat match and region items that start at the same place',
    \ '  - among match/region items, the one defined LAST wins when both start',
    \ '    at the same position; an item that starts earlier keeps priority',
    \ '    until it ends (unless the later one has a higher "priority" or it',
    \ '    is contained in it)',
    \ '  - "contained" items only apply inside items that list them in',
    \ '    contains= (or via containedin=); "transparent" items take the',
    \ '    colour of what contains them',
    \ '  - the innermost item in the stack supplies the colour; :SynCursor',
    \ '    shows that stack for the cursor position',
    \ '  - after syntax, :match/matchadd() and text properties can still',
    \ '    override the colour',
    \ '']
  if empty(a:group)
    let l:out = execute('verbose syntax list', 'silent!')
    for l:l in split(l:out, "\n")
      if l:l =~# 'Last set from'
        let [l:file, l:lnum] = s:last_set(l:l)
        call add(l:lines, '    ' . substitute(s:source_line(l:file, l:lnum), '^set from', 'rule from', ''))
      else
        call add(l:lines, l:l)
      endif
    endfor
  else
    call add(l:lines, 'Rule ' . a:group . ':')
    call extend(l:lines, s:rule_lines(a:group, ''))
    call add(l:lines, '')
    call extend(l:lines, s:group_lines(a:group, ''))
  endif
  call s:scratch('SynRules' . (empty(a:group) ? '' : ' ' . a:group), l:lines, 0)
endfunction

" ------------------------------------------------------------ scratch

" Group names that appear in the report, with their positions, so each can
" be drawn in its own highlight: stack items ("1. name"), link chains
" ("link chain: a -> b"), and "Group: name" / "Rule name:" headings.
function! s:group_samples(lines) abort
  let l:samples = []
  let l:lnum = 0
  for l:line in a:lines
    let l:lnum += 1
    let l:m = matchstrpos(l:line, '^\d\+\. \zs\S\+')
    if l:m[1] >= 0
      call add(l:samples, [l:m[0], l:lnum, l:m[1] + 1, len(l:m[0])])
      continue
    endif
    let l:m = matchstrpos(l:line, '^\s*link chain: \zs.*')
    if l:m[1] >= 0
      let l:col = l:m[1]
      for l:part in split(l:m[0], ' -> ')
        call add(l:samples, [l:part, l:lnum, l:col + 1, len(l:part)])
        let l:col += len(l:part) + 4
      endfor
      continue
    endif
    let l:m = matchstrpos(l:line, '^\%(Highlight group\|Rule\) \zs\S\+')
    if l:m[1] >= 0
      call add(l:samples, [l:m[0], l:lnum, l:m[1] + 1, len(l:m[0])])
    endif
  endfor
  return l:samples
endfunction

" Show lines in a scratch window. The buffer is unlisted, kept out of the
" jumplist and alternate-file history, and wiped as soon as it is hidden or
" closed; ":w {name}" turns it into an ordinary file buffer instead.
" "samples" is a list of [group, lnum, col, len] to draw with that group.
function! s:scratch(title, lines, samples) abort
  let l:name = '[' . a:title . ']'
  " Reuse a window that already shows one of our reports, else split.
  let l:win = 0
  for l:w in range(1, winnr('$'))
    if getbufvar(winbufnr(l:w), 'synexplore_report', 0)
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
  setlocal buftype=acwrite bufhidden=wipe noswapfile nobuflisted
  setlocal modifiable noreadonly
  let b:synexplore_report = 1
  let l:n = 0
  let l:try = l:name
  while bufexists(l:try)
    let l:n += 1
    let l:try = '[' . a:title . ' ' . l:n . ']'
  endwhile
  execute 'silent keepalt file' fnameescape(l:try)
  call setline(1, a:lines)
  setlocal nomodified nowrap
  setlocal filetype=synexplore
  call clearmatches()
  let l:samples = (empty(a:samples) ? [] : a:samples) + s:group_samples(a:lines)
  for l:s in l:samples
    if hlexists(l:s[0])
      silent! call matchaddpos(l:s[0], [[l:s[1], l:s[2], l:s[3]]])
    endif
  endfor
  call cursor(1, 1)
  " Read-only like a help window; yanking and searching still work.
  setlocal nomodifiable
endfunction

" ":w {name}" in a report: save it, then open the saved file in place of
" the report as an ordinary buffer (the report itself is wiped). It keeps
" the report highlighting through 'syntax' alone, so it behaves like any
" other file from then on. Installed per buffer by the ftplugin.
function! synexplore#write() abort
  let l:target = expand('<afile>')
  if empty(l:target) || l:target =~# '^\[.*\]$'
    echohl ErrorMsg
    echomsg 'synexplore: give a file name to keep this report, e.g. :w notes.txt'
    echohl None
    return
  endif
  if writefile(getline(1, '$'), l:target) != 0
    echohl ErrorMsg | echomsg 'synexplore: could not write ' . l:target | echohl None
    return
  endif
  setlocal nomodified
  execute 'keepalt keepjumps edit!' fnameescape(l:target)
  setlocal syntax=synexplore
  echomsg 'synexplore: written ' . fnamemodify(l:target, ':~') . '; this buffer now stays'
endfunction
