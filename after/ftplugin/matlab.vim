" Layered on top of $VIMRUNTIME/ftplugin/matlab.vim instead of replacing it.
" Sourced from after/, so by the time this runs the runtime file has already
" set commentstring, suffixesadd, suffixes and matchit's b:match_words. There
" is deliberately no b:did_ftplugin guard here: setting that is what made the
" runtime file bail out when these settings lived in ftplugin/matlab.vim.

setlocal shiftwidth=2
setlocal softtabstop=-1

" Matlab's editor indents function bodies a level ("Indent all functions");
" indent/matlab.vim copies that with a default of 2. 0 is its Classic mode:
" the body starts at column 0 and only if/for/while nest. This has to be the
" global, not b:MATLAB_function_indent, because indent/matlab.vim is sourced
" after every ftplugin, this one included, and opens with
"     let b:MATLAB_function_indent = get(g:, 'MATLAB_function_indent', 2)
" which would overwrite a buffer-local set here.
let g:MATLAB_function_indent = 0

" matchit: the runtime file pairs function with endfunction, which is
" Octave's spelling, and lets only if, switch, for, while and try close on
" end. In Matlab a function closes on end like everything else, as do
" classdef and its blocks, parfor and spmd. So the words are redefined
" here with every block opener in one group, so that % on function lands
" on its end and skips the nested blocks in between. An end is only the
" one that starts a statement: x(end) and x{end-1} are indexing, and the
" runtime's lookbehind is kept for that, extended to a comma so that the
" end of "for i = 1:3, y = i, end" counts. The comma is written \%d44:
" matchit splits the words on literal commas and colons. break, continue
" and return are statements rather than structure and are left out of the
" cycle.
if exists('loaded_matchit')
  let b:match_words =
    \ '\<\%(if\|switch\|for\|parfor\|while\|try\|function\|classdef\|methods\|properties\|events\|enumeration\|arguments\|spmd\)\>'
    \ . ':\<\%(elseif\|else\|case\|otherwise\|catch\)\>'
    \ . ':\%(\%(^\|;\|\%d44\)\s*\)\@<=end\>'
endif

" K opens Matlab's own help for the word under the cursor, out of the index
" plugin/matlabdoc.vim builds. Without an index the first lookup starts Matlab
" and takes a few seconds; :MatlabDocIndex removes that for good.
setlocal keywordprg=:MatlabDoc

" :make runs this file in the warm Matlab session and puts any error in the
" quickfix list. See compiler/matlab.vim and |matlabserver-make|.
compiler matlab

" Add to the runtime file's undo command rather than replacing it, so
" :setfiletype something-else still restores everything.
let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal shiftwidth< softtabstop< keywordprg< makeprg< errorformat<'
  \ . ' | unlet! b:current_compiler'
