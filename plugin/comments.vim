if exists('g:plugin_comments')
  finish
endif
let g:plugin_comments = v:true

" Comments placed into this map should be unescaped string literals.
let g:comment_map = {
  \ "c": '//',
  \ "cpp": '//',
  \ "racket": ';;;',
  \ "scheme": ';;;',
  \ "sh": '#',
  \ "tex": '%',
  \ "typst": '//',
  \ "vim": '"',
  \ }

function! s:ProcessCommentRange(start_line, end_line) abort
  if !has_key(g:comment_map, &filetype)
    echohl WarningMSG
    echom "No comment leader for filetype `" . 
      \ &filetype . "` in comment_map"
    echom "Suggestion: add `" . &filetype . 
      \ "` to the comment_map"
    echo  "No comment leader for filetype `" . 
      \ &filetype . "` in comment_map"
    echohl None
    return
  endif

  let l:leader = g:comment_map[&filetype]
  let l:escaped_leader = escape(l:leader, '\*^$.~[]/')

  " The first line of the target range determines the toggle state
  let l:first_line = getline(a:start_line)
  let l:is_commented = (l:first_line =~# '^\s*' . l:escaped_leader)

  let l:save_cursor = getpos('.')

  " Begin toggling comments line by line
  for lnum in range(a:start_line, a:end_line)
    let l:line = getline(lnum)

    " Do not comment empty lines by default
    if l:line =~# '^\s*$'
      continue
    endif

    " Toggle comments on/off
    if l:is_commented
      execute 'silent! ' . lnum . 's/^\(\s*\)' . 
        \ l:escaped_leader . ' \?/\1/'
    else
      let l:repl_leader = escape(l:leader, '/\&')
      execute 'silent! ' . lnum . 's/^\(\s*\)/\1' . 
        \ l:repl_leader . ' /'
    endif
  endfor

  call setpos('.', l:save_cursor)
endfunction

function! s:NormalComment(type) abort
  let l:start_line = line("'[")
  let l:end_line = line("']")
  call s:ProcessCommentRange(l:start_line, l:end_line)
endfunction

function! s:VisualComment() abort
  let l:start_line = line("'<")
  let l:end_line = line("'>'")
  call s:ProcessCommentRange(l:start_line, l:end_line)
endfunction

nnoremap <silent> gc :set operatorfunc=<SID>NormalComment<CR>g@
xnoremap <silent> gc :<C-u>call <SID>VisualComment()<CR>
nnoremap <silent> gcc :set operatorfunc=<SID>NormalComment<CR>g@_
