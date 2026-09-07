" The bundled syntax does not highlight call sites; match name( like typst.
" Keywords win over matches, so 'if (' and 'print(' are unaffected.
" Coloured by colors/custom.vim.
syn match pythonFunctionCall "\<\h\w*\ze\s*(" display
