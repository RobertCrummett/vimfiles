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
" The session is a separate Matlab process with its own workspace. It does
" not share anything with a Matlab desktop you have open, and does not stop
" you opening one: an Individual licence lets the same user run several
" sessions at once. Keep the desktop for the debugger; this one is for
" running things without waiting.
"
" g:matlabserver_port    port to listen on (51763)
" g:matlabserver_timeout how long to wait for a reply, ms (60000)
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
