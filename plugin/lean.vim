" Lean 4: what has to exist outside a Lean buffer. The rest is in
" ftplugin/lean.vim, compiler/lean.vim and syntax/lean.vim. See |lean-local|.
if exists('g:loaded_lean')
  finish
endif
let g:loaded_lean = 1

command! -bar LeanSymbols call lean#list()

" QuickFixCmdPost matches on the command, not the buffer, so it cannot be
" set up by the filetype plugin. The buffer :make ran in is still current.
augroup lean_make
  autocmd!
  autocmd QuickFixCmdPost make
    \ if get(b:, 'current_compiler', '') ==# 'lean' | call lean#quickfix(0) | endif
  autocmd QuickFixCmdPost lmake
    \ if get(b:, 'current_compiler', '') ==# 'lean' | call lean#quickfix(1) | endif
augroup END
