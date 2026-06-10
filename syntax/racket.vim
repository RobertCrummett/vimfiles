syntax keyword racketBase newline containedin=ALLBUT,racketComment
highlight default link racketBase racketFunc

" Syntax highlighting for lang sicp files. Especially useful while
" reading through the SICP book.

if !exists('b:sicp_syntax_active')
  let b:sicp_syntax_active = 0
endif

function! s:ToggleSICPSyntax() abort
  let l:is_sicp = (getline(1) ==# '#lang sicp')

  if l:is_sicp && !b:sicp_syntax_active
    syntax keyword SICPFunc cons-stream containedin=ALLBUT,racketComment
    syntax keyword SICPFunc stream-null? containedin=ALLBUT,racketComment
    highlight default link SICPFunc racketFunc
    
    let b:sicp_syntax_active = 1
  elseif !l:is_sicp && b:sicp_syntax_active
    syntax clear SICPFunc

    let b:sicp_syntax_active = 0
  endif
endfunction

call s:ToggleSICPSyntax()

augroup SICPCheck
  au! * <buffer>
  au InsertLeave,TextChanged,TextChangedI <buffer> call s:ToggleSICPSyntax()
augroup END
