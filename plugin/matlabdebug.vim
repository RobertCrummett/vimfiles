" matlabdebug: debug Matlab code in Vim, using the warm session that
" plugin/matlabserver.vim keeps. The line Matlab is stopped on is marked in
" the source, the stack and the variables of the selected frame have windows
" of their own, and stepping is a command away.
"
"   :MatlabDebug          open the debugger: two windows, and the commands
"   :MatlabDebugClose     close it; breakpoints are kept for next time
"
" While it is open, named after Vim's own termdebug:
"
"   :Run [file]           run the file (default: the current buffer)
"   :Break [line] [if cond]  toggle a breakpoint; :Clear [line] removes one
"   :Step  :Over  :Finish :Continue  :Stop    dbstep in, dbstep, dbstep out,
"                                              dbcont, dbquit
"   :Up  :Down  :Frame N  select a frame; the variables window follows
"   :Evaluate [expr]      evaluate in the selected frame (bare: the word
"                         under the cursor; :'<,'>Evaluate the selection)
"   :Watch expr           show expr in the variables window at every stop
"   :Unwatch expr|N       stop showing it
"
" A :make or :Matlab that reaches a breakpoint opens the debugger by itself.
" See :help matlabdebug, and :help matlabdebug-workaround for what the
" session's side of this rests on and why it is not to be relied on for
" the long term.
"
" g:matlabdebug_width       width of the variables and stack column (45)
" g:matlabdebug_break_sign  the breakpoint sign's text (●)
" g:matlabdebug_pc_sign     margin text on the stopped line (none)
if exists('g:loaded_matlabdebug')
  finish
endif
let g:loaded_matlabdebug = 1

command! -bar MatlabDebug      call matlabdebug#open()
command! -bar MatlabDebugClose call matlabdebug#close()

" A file with breakpoints opened after they were set gets its signs.
augroup matlabdebug
  autocmd!
  autocmd BufReadPost *.m call matlabdebug#buffer_loaded()
augroup END
