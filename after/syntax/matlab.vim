" Also sourced for octave (syntax/octave.vim does 'runtime! syntax/matlab.vim').
"
" The bundled syntax hands the '...' line continuation to matlabComment: it
" matches "\.\.\..*$" as a comment at line 65, after the matlabLineContinuation
" rule at line 37, and of two matches starting at the same place the later one
" wins. Treating the text after the dots as a comment is right, Matlab ignores
" it, but the dots themselves are punctuation and reading them as a comment
" hides where the statement carries on.
"
" Take that one rule over, under a name of our own so the plain "%" comment is
" left alone, and let matlabLineContinuation match the dots inside it. A '...'
" written in a real comment stays comment-coloured, because matlabComment does
" not contain matlabLineContinuation.
" Coloured by colors/custom.vim.
syn match matlabContinuedComment "\.\.\..*$"
  \ contains=matlabTodo,matlabTab,matlabLineContinuation
syn match matlabLineContinuation "\.\{3}" contained

hi def link matlabContinuedComment Comment
