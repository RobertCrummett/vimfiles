" matlabdoc: read Matlab's own help text without leaving Vim.
"
"   :MatlabDoc [name]    help for {name}, or for the word under the cursor
"   :MatlabDocIndex      (re)build the offline index; about a minute and a half
"   :MatlabDocStatus     when the index was built and how much it holds
"   :MatlabDocClear      forget answers Matlab was asked for live
"
" K is wired to :MatlabDoc in matlab buffers, so pressing K on exp
" opens Matlab's help for exp.
"
" Matlab needs about five seconds to start, which is too slow to pay per
" lookup, so it is run once: matlab/build_index.m walks every function in
" matlabroot/help/matlab/helpfuncbycat.xml and writes its help text to
" matlab/index/. A lookup is then a file read. Names the index misses -
" your own functions, mostly - fall back to "matlab -batch help {name}" in a
" background job, cached for the session.
"
" The index is generated, so .gitignore keeps it out of the history; the
" generator itself is tracked. Rebuild it after a Matlab upgrade.
"
" g:matlabdoc_program overrides which matlab.exe to run.
if exists('g:loaded_matlabdoc')
  finish
endif
let g:loaded_matlabdoc = 1

command! -bar -nargs=? MatlabDoc       call matlabdoc#open(<q-args>)
command! -bar          MatlabDocIndex  call matlabdoc#index()
command! -bar          MatlabDocStatus call matlabdoc#index_status()
command! -bar          MatlabDocClear  call matlabdoc#clear()
