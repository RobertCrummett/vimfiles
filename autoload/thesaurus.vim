" Thesaurus completion (CTRL-X CTRL-T) backed by the Moby Thesaurus.
"
" Vim's built-in 'thesaurus' handling rescans the whole file on every
" completion and silently truncates lines longer than 510 bytes, which cuts
" most Moby entries short. This 'thesaurusfunc' loads the file once into a
" dictionary keyed by headword and answers from memory.
"
" File: thesaurus/mthesaur.txt next to this repo's autoload/ directory
" (untracked; see README for where to get it). Override with
" g:thesaurus_file.

let s:file = get(g:, 'thesaurus_file', expand('<sfile>:p:h:h') . '/thesaurus/mthesaur.txt')
let s:index = {}
let s:loaded = 0

function! s:load() abort
  if s:loaded
    return 1
  endif
  let s:loaded = 1
  if !filereadable(s:file)
    echohl WarningMsg
    echomsg 'thesaurus: file not found: ' . s:file . ' (see README)'
    echohl None
    return 0
  endif
  " Keep the raw line per headword; split only when asked.
  for l:line in readfile(s:file)
    let l:comma = stridx(l:line, ',')
    if l:comma > 0
      let s:index[strpart(l:line, 0, l:comma)] = l:line
    endif
  endfor
  return 1
endfunction

function! s:synonyms(head) abort
  let l:line = get(s:index, a:head, '')
  if empty(l:line)
    return []
  endif
  let l:words = split(substitute(l:line, '\r$', '', ''), ',')
  return l:words[1:]
endfunction

function! s:match_case(word, base) abort
  if a:base =~# '^\u\+$' && len(a:base) > 1
    return toupper(a:word)
  elseif a:base =~# '^\u'
    return toupper(a:word[0]) . a:word[1:]
  endif
  return a:word
endfunction

" 'thesaurusfunc' entry point.
function! thesaurus#complete(findstart, base) abort
  if a:findstart
    let l:line = getline('.')
    let l:col = col('.') - 1
    while l:col > 0 && l:line[l:col - 1] =~# '\k'
      let l:col -= 1
    endwhile
    return l:col
  endif
  if !s:load() || empty(a:base)
    return []
  endif
  let l:key = tolower(a:base)
  let l:words = s:synonyms(l:key)
  if !empty(l:words)
    " Exact headword: offer its synonyms.
    return map(l:words, '{"word": s:match_case(v:val, a:base), "menu": "syn"}')
  endif
  " Partial word: offer headwords that start with it, so the word can be
  " completed first and CTRL-X CTRL-T pressed again for synonyms.
  let l:heads = sort(filter(keys(s:index), 'stridx(v:val, l:key) == 0'))
  return map(l:heads, '{"word": s:match_case(v:val, a:base), "menu": "word"}')
endfunction
