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

" Keywords syntax/matlab.vim never lists, so they match nothing and take the
" Normal colour: continue, parfor, spmd, arguments and enumeration. The two
" runtime files disagree about these - indent/matlab.vim already counts parfor,
" spmd and enumeration among its block openers (s:open_pat).
syn keyword matlabStatement continue
syn keyword matlabRepeat    parfor
syn keyword matlabOO        spmd arguments enumeration

" break is upstream in matlabOperator, sharing a group with function names
" like zeros, round and rand. Put it with return and continue the way
" syntax/c.vim keeps goto, break, return and continue together. This also
" keeps it once the clear below empties matlabOperator.
syn keyword matlabStatement break

" syntax/matlab.vim lights up an arbitrary forty-odd built-in names out of
" the thousands Matlab ships, and none of the functions you write yourself:
" exp and sqrt come from matlabImplicit, mean and zeros from matlabOperator,
" error and eval from matlabFunction, while numel, linspace and your own
" helpers get nothing. A subset like that reads as though the lit names were
" special, so drop the lot and leave every call plain.
"
" Only the keyword lists go. matlabOperator keeps its name and its
" highlighting for the +, -, ==, & and ' matches that link to it, so the
" real operators are untouched.
syn clear matlabOperator
syn clear matlabImplicit

" matlabFunction held error and eval next to the function keyword itself.
" Clear it and put the keyword back.
syn clear matlabFunction
syn keyword matlabFunction function
