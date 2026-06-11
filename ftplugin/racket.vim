if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

compiler racket

setlocal autoindent
setlocal lisp
setlocal lispwords=define,if,cond,else,and,or,let,begin,lambda,mu,quote,delay,cons-stream,set!,quasiquote,unquote,unquote-splicing,define-macro

" Removes two characters.
" First character is at the initial position.
" Second character is at the position 'final'
function! s:DeletePair(final) abort
  execute "normal! x"
  call setpos('.', a:final)
  execute "normal! x"
endfunction

function! s:DeleteParens() abort
  let l:pos = getpos('.')
  let l:eol = l:pos[2] == (col('$') - 1)

  " let l:char = matchstr(getline(l:pos[1]), '\%' . l:pos[2] . 'c.')
  " if l:char =~# "[()]"
    " " Character is not paren.
    " echoe "The current chraracter is not a paren. This function expected paren."
  " endif

  execute "normal! %"
  let l:other = getpos('.') 

  " The parens are in different rows.
  " The can be removed without shifting
  " one another.
  if l:pos[1] != l:other[1]
    call s:DeletePair(l:pos)
  else
    " The parens are in the same row.
    " Removal of one may move the other,
    " so we need to adjust the final position
    " if this is the case.
    if l:other[2] < l:pos[2]
      let l:pos[2] -= 1
      call s:DeletePair(l:pos)
    elseif l:pos[2] < l:other[2]
      call s:DeletePair(l:pos)
    else
      " No matching parenthesis. This should
      " effectively fall through.
      execute "normal! x"
    endif
  endif

  " Return to insert mode after deletion
  if l:eol
    call feedkeys('A', 'n')
  else
    startinsert
  endif
endfunction

inoremap <buffer> ( ()<esc>i
inoremap <buffer> ) ()<esc>i
inoremap <buffer> <silent> <expr> <BS>  
  \ (col('.') > 1 && getline('.')[col('.') - 2] =~# '[()]')
  \ ? "\<ESC>:call <SID>DeleteParens()\<CR>"
  \ : "\<BS>"
inoremap <buffer> <silent> <expr> <C-h> 
  \ (col('.') > 1 && getline('.')[col('.') - 2] =~# '[()]')
  \ ? "\<ESC>:call <SID>DeleteParens()\<CR>"
  \ : "\<C-h>"
