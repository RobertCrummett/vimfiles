if exists('g:plugin_comments')
  finish
endif
let g:plugin_comments = v:true

" Comments placed into this map should be unescaped string literals.
let g:comment_map = {
  \ "c": '//',
  \ "cpp": '//',
  \ "racket": ';;',
  \ "scheme": ';;',
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
  let l:leader_len = len(l:leader)

  " Find first non-empty line to establish whether we are commenting
  " or uncommenting, and the base level of indentation.
  let l:first_lnum = a:start_line
  while l:first_lnum <= a:end_line && getline(l:first_lnum) =~# '^\s*$'
    let l:first_lnum += 1
  endwhile

  if l:first_lnum > a:end_line
    return
  endif

  let l:first_line = getline(l:first_lnum)

  let l:base_indent = matchstr(l:first_line, '^\s*')
  let l:base_indent_len = len(l:base_indent)

  " The first line of the target range determines the toggle state
  let l:is_commented = (l:first_line =~# '^\s*\V' . escape(l:leader, '\'))

  let l:save_cursor = getpos('.')

  " Begin toggling comments line by line
  for l:lnum in range(l:first_lnum, a:end_line)
    let l:line = getline(l:lnum)

    " Do not comment empty lines by default
    if l:line =~# '^\s*$'
      continue
    endif

    " Toggle comments on/off
    if l:is_commented
      let l:line_indent = matchstr(l:line, '^\s*')
      let l:text = strpart(l:line, len(l:line_indent))

      if strpart(l:text, 0, l:leader_len) ==# l:leader
        let l:text = strpart(l:text, l:leader_len)
        if len(l:text) > 0 && l:text[0] ==# ' '
          let l:text = strpart(l:text, 1)
        endif
        call setline(l:lnum, l:line_indent . l:text)
      endif
    else
      if strpart(l:line, 0, l:base_indent_len) ==# l:base_indent
        let l:new_line = l:base_indent . l:leader . ' ' . strpart(l:line, l:base_indent_len)
      else
        let l:line_indent = matchstr(l:line, '^\s*')
        let l:new_line = l:line_indent . l:leader . ' ' . strpart(l:line, len(l:line_indent))
      endif
      call setline(l:lnum, l:new_line)
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
  let l:end_line = line("'>")
  call s:ProcessCommentRange(l:start_line, l:end_line)
endfunction

nnoremap <silent> gc :set operatorfunc=<SID>NormalComment<CR>g@
xnoremap <silent> gc :<C-u>call <SID>VisualComment()<CR>
nnoremap <silent> gcc :set operatorfunc=<SID>NormalComment<CR>g@_
