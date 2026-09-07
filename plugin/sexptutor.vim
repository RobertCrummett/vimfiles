" sexptutor: open a practice copy of the vim-sexp tutor.
"
"   :SexpTutor      copy tutor/sexptutor.txt to a temporary .scm file and
"                   edit it, so the scheme filetype and vim-sexp mappings
"                   are active and the original stays untouched
"   :SexpTutor!     open the original tutor file itself
if exists('g:loaded_sexptutor')
  finish
endif
let g:loaded_sexptutor = 1

let s:tutor = expand('<sfile>:p:h:h') . '/tutor/sexptutor.txt'

function! s:open(original) abort
  if !filereadable(s:tutor)
    echohl ErrorMsg | echomsg 'SexpTutor: missing ' . s:tutor | echohl None
    return
  endif
  if a:original
    execute 'edit' fnameescape(s:tutor)
    return
  endif
  let l:copy = tempname() . '-sexptutor.scm'
  call writefile(readfile(s:tutor), l:copy)
  execute 'edit' fnameescape(l:copy)
  setlocal filetype=scheme noswapfile
  setlocal textwidth=0 formatoptions-=t
  " Prose lines must not be re-indented as code by the structural commands.
  setlocal noautoindent nosmartindent indentexpr=
  echo 'SexpTutor: this is a copy; edit freely. :SexpTutor! opens the original.'
endfunction

command! -bar -bang SexpTutor call s:open(<bang>0)
