" prose: while 'spell' is on in a Typst or LaTeX window, everything that is
" not prose is drawn in grey, so that only the text being proofread stands
" out. Comments stay as they are. Turning 'spell' off brings the colours back.
"
"   :set spell / :set nospell     that is all there is to it
"   let g:prose = 0               never grey anything
"   let g:prose_eager = 1         prepare when a file is opened, so that the
"                                 first :set spell is immediate
"
" The grey is the highlight group proseCode. What counts as code is decided
" by a scanner for the language, not by the syntax file; see :help prose.
if exists('g:loaded_prose') || !has('textprop') || !exists('*listener_add') || !has('timers')
  finish
endif
let g:loaded_prose = 1

highlight default link proseCode Comment

augroup prose
  autocmd!
  " 'spell' is not set through OptionSet while Vim starts ("vim -c 'set
  " spell' x.typ"), hence VimEnter. The tests keep the autoload files from
  " being read until there is a buffer for them; b:prose is set on a buffer
  " that is marked, which must be unmarked even when its filetype changes.
  autocmd OptionSet spell
        \ if &filetype ==# 'typst' || &filetype ==# 'tex' | call prose#sync() | endif
  autocmd FileType,BufWinEnter,BufEnter,WinEnter,VimEnter *
        \ if &filetype ==# 'typst' || &filetype ==# 'tex' || get(b:, 'prose', 0) | call prose#sync() | endif
  " A colorscheme that does not know the group takes the default link with it.
  autocmd ColorScheme * highlight default link proseCode Comment
augroup END
