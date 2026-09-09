" XXX Commented out because I am not sure that these should be
" highlighted if by default they are not. I should just go with
" the defaults probably. But leaving this here incase it looks bad.
"
" syntax keyword racketBase newline containedin=ALLBUT,racketComment
" highlight default link racketBase racketFunc

function! s:ToggleSICPSyntax()
  " Applies syntax highlighting specific to MIT Scheme used in SICP.
  let l:is_sicp = (getline(1) =~# '^#lang sicp$')
  if l:is_sicp
    " Added to @racketTop, the cluster the racketStruc paren regions contain,
    " rather than with containedin=ALLBUT: that reached inside strings and
    " #| |# block comments too, so "inc" in a string came out a function.
    syntax keyword SICPBuiltin
      \ nil inc dec the-empty-stream cons-stream stream-null?
      \ runtime random amb true false identity error
    syntax cluster racketTop add=SICPBuiltin
    highlight default link SICPBuiltin racketFunc
  else
    silent! syntax clear SICPBuiltin
  endif
endfunction

" This file is sourced once per racket buffer, so the clear has to name the
" buffer: a bare "au!" would empty the whole group and leave every racket
" buffer opened earlier without its toggle.
augroup ToggleSICP
  au! * <buffer>
  au BufEnter,BufWrite <buffer> call s:ToggleSICPSyntax()
augroup END
