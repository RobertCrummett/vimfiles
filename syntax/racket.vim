syntax keyword racketBase newline containedin=ALLBUT,racketComment
highlight default link racketBase racketFunc

function! s:ToggleSICPSyntax() abort
  " Applies syntax highlighting specific to MIT Scheme used in SICP.
  let l:is_sicp = (getline(1) =~# '^#lang sicp$')
  if l:is_sicp
    syntax keyword SICPFunc cons-stream containedin=ALLBUT,racketComment
    syntax keyword SICPFunc stream-null? containedin=ALLBUT,racketComment
    highlight default link SICPFunc racketFunc
  else
    silent! syntax clear SICPFunc
  endif
endfunction

augroup ToggleSICP
  au! * <buffer>
  au BufEnter,BufWrite <buffer> call s:ToggleSICPSyntax()
augroup END
