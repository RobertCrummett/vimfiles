" bgmake: :make in the background.
"
"   :make               in a buffer whose filetype is in g:bgmake_filetypes,
"                       write the buffer, return at once and run 'makeprg' as
"                       a job; the quickfix list is filled when it ends
"
" Nothing jumps and no window opens when it ends, because the cursor may be
" anywhere by then. It says how it went, and :clist has the errors.
"
" :make cannot be pointed at a Vim function, but it can be stopped. It fires
" QuickFixCmdPre and then returns if the autocommand aborted, and interrupt()
" is how an autocommand aborts: CTRL-C with nothing on the screen. So this is
" reached by every :make, typed or from a mapping or a script, which an
" abbreviation is not, and :make in any other buffer is untouched.
"
" Nothing may print before interrupt(): a message on the screen turns the
" silent stop into "Interrupt: Press ENTER". So the work waits for a timer.
"
" See |bgmake|.
if exists('g:loaded_bgmake') || !has('job') || !exists('*interrupt')
  finish
endif
let g:loaded_bgmake = 1

let g:bgmake_filetypes = get(g:, 'bgmake_filetypes', ['tex'])

augroup bgmake
  autocmd!
  autocmd QuickFixCmdPre make if index(g:bgmake_filetypes, &filetype) >= 0
    \ | call timer_start(0, function('bgmake#make')) | call interrupt() | endif
augroup END
