" matlabserver: keep one Matlab session alive and talk to it over a socket,
" so running something costs milliseconds instead of Matlab's five second
" startup.
"
"   :MatlabStart          start the session (a few seconds, once)
"   :MatlabStop           shut it down
"   :MatlabStatus         is it up, and how fast is the round trip
"   :Matlab {command}     evaluate {command} in it
"   :MatlabRun            write the current file and run it
"
" :make in a matlab buffer runs the file through the session too, and puts
" whatever raised into the quickfix list for :clist and :cnext. It starts the
" session first if there is not one. See compiler/matlab.vim.
"
" The session is a separate Matlab process with its own workspace. It does
" not share anything with a Matlab desktop you have open, and does not stop
" you opening one: an Individual licence lets the same user run several
" sessions at once. Keep the desktop for the debugger; this one is for
" running things without waiting.
"
" g:matlabserver_port    port to listen on (51763)
" g:matlabserver_timeout how long to wait for a reply, ms (60000)
" g:matlabserver_python  python that runs mlmake.py for :make ("python")
" g:matlabserver_start_timeout  how long :make waits for a session (30000)
" g:matlabdoc_program    which matlab.exe to run, shared with matlabdoc
if exists('g:loaded_matlabserver')
  finish
endif
let g:loaded_matlabserver = 1

command! -bar          MatlabStart  call matlabserver#start()
command! -bar          MatlabStop   call matlabserver#stop()
command! -bar          MatlabStatus call matlabserver#status()
command! -bar          MatlabRun    call matlabserver#run()
command! -nargs=+      Matlab       call matlabserver#eval(<q-args>)

" :make in a Matlab buffer runs the file through the session (see
" compiler/matlab.vim), so there has to be one. QuickFixCmdPre fires before
" :make shells out, which is the one moment we can still start it; :make is
" synchronous, so this waits rather than starting in the background.
"
" The buffer is written first. :make on a stale file is a trap, and Vim's own
" answer to it, 'autowrite', is a global setting this should not turn on.
augroup matlabserver_make
  autocmd!
  autocmd QuickFixCmdPre make,lmake call matlabserver#make_pre()
augroup END
