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

" K opens Matlab's own help for the word under the cursor, out of the index
" plugin/matlabdoc.vim builds. Without an index the first lookup starts Matlab
" and takes a few seconds; :MatlabDocIndex removes that for good.
setlocal keywordprg=:MatlabDoc

" Add to the runtime file's undo command rather than replacing it, so
" :setfiletype something-else still restores everything.
let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal shiftwidth< softtabstop< keywordprg<'
