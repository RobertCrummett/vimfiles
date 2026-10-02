" typstprose: while 'spell' is on in a Typst window, everything that is not
" prose is drawn in grey, so that only the text being proofread stands out.
" Comments stay as they are. Turning 'spell' off brings the colours back.
"
"   :set spell / :set nospell     that is all there is to it
"   let g:typstprose = 0          never grey anything
"   let g:typstprose_eager = 1    prepare when a Typst file is opened, so
"                                 that the first :set spell is immediate
"
" The grey is the highlight group typstProseCode. What counts as code is
" decided by a scanner that follows Typst's own parser, not by the syntax
" file; see :help typstprose.
if exists('g:loaded_typstprose') || !has('textprop') || !exists('*listener_add') || !has('timers')
  finish
endif
let g:loaded_typstprose = 1

highlight default link typstProseCode Comment

augroup typstprose
  autocmd!
  " 'spell' is not set through OptionSet while Vim starts ("vim -c 'set
  " spell' x.typ"), hence VimEnter. The test keeps the autoload file from
  " being read until there is a Typst buffer; b:typstprose is set on a
  " buffer that is marked, which must be unmarked even when it stops being
  " Typst.
  autocmd OptionSet spell
        \ if &filetype ==# 'typst' | call typstprose#sync() | endif
  autocmd FileType,BufWinEnter,BufEnter,WinEnter,VimEnter *
        \ if &filetype ==# 'typst' || get(b:, 'typstprose', 0) | call typstprose#sync() | endif
  " A colorscheme that does not know the group takes the default link with it.
  autocmd ColorScheme * highlight default link typstProseCode Comment
augroup END
