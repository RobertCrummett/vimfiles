" NOTE: Commented out because I am not sure that these should be
" highlighted if by default they are not. I should just go with
" the defaults probably. But leaving this here incase it looks bad.
"
" syntax keyword racketBase newline containedin=ALLBUT,racketComment
" highlight default link racketBase racketFunc

function! s:ToggleSICPSyntax()
  " Applies syntax highlighting specific to MIT Scheme used in SICP.
  let l:is_sicp = (getline(1) =~# '^#lang sicp$')
  if l:is_sicp
    syntax keyword SICPBuiltin 
      \ nil inc dec the-empty-stream cons-stream stream-null?
      \ runtime random amb true false identity error
      \ containedin=ALLBUT,racketComment
    highlight default link SICPBuiltin racketFunc
  else
    silent! syntax clear SICPBuiltin
  endif
endfunction

augroup ToggleSICP
  au!
  au BufEnter,BufWrite <buffer> call s:ToggleSICPSyntax()
augroup END
