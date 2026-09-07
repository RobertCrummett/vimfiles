" Vim ships no octave syntax. Reuse matlab's the way cpp reuses c; this also
" pulls in after/syntax/matlab.vim.
if exists('b:current_syntax')
  finish
endif
runtime! syntax/matlab.vim
let b:current_syntax = 'octave'
