" matlabserver: keep one Matlab session alive and talk to it over a socket,
" so running something costs milliseconds instead of Matlab's five second
" startup.
"
"   :MatlabStart          start the session (a few seconds, once)
"   :MatlabStop           shut it down
"   :MatlabStatus         is it up, and how fast is the round trip
"   :Matlab {command}     evaluate {command} in it
"   :MatlabRun            write the current file and run it
"   :MatlabMake[!]        run it and put errors in the quickfix list
"
" Typing :make in a matlab buffer runs :MatlabMake, so errors land in the
" quickfix list for :clist and :cnext. It starts the session if there is not
" one. See |matlabserver-make|.
"
" The session is a separate Matlab process with its own workspace. It does
" not share anything with a Matlab desktop you have open, and does not stop
" you opening one: an Individual licence lets the same user run several
" sessions at once. Keep the desktop for the debugger; this one is for
" running things without waiting.
"
" g:matlabserver_port    port to listen on (51763)
" g:matlabserver_timeout how long to wait for a reply, ms (60000)
" g:matlabserver_start_timeout  how long :MatlabMake waits for a session (30000)
" g:matlabserver_make_abbrev    let typed :make mean :MatlabMake (1)
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
command! -bar -bang    MatlabMake   call matlabserver#make(<bang>0)

" Typing :make in a Matlab buffer runs :MatlabMake, which goes through the
" session rather than starting Matlab again.
"
" :make itself cannot be pointed at a Vim function: it runs 'makeprg' through
" the shell, so routing it through the session would need an external program
" that speaks to the socket, and none ships with Vim, Windows or Matlab.
" Abbreviating the typed command keeps the dependency list where it is.
"
" It fires only when "make" is the whole command line so far and only in a
" Matlab buffer, so :make elsewhere, :makeprg and the like are untouched, and
" what ran is visible on the command line rather than hidden. A :make from a
" script or a mapping is not abbreviated and falls to 'makeprg', which
" compiler/matlab.vim points at matlab -batch: correct, and slow, and needing
" no session.
"
" Set g:matlabserver_make_abbrev to 0 to keep :make literal.
if get(g:, 'matlabserver_make_abbrev', 1)
  " No "||" in here: a bar in the right-hand side of an abbreviation ends
  " the command, so the expression would be stored truncated and fail with
  " E110 every time it fired, taking the command line down with it.
  cnoreabbrev <expr> make
    \ (getcmdtype() ==# ':' && getcmdline() ==# 'make'
    \   && &filetype ==# 'matlab') ? 'MatlabMake' : 'make'
endif
