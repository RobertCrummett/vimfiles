" bgmake: :make in the background.
"
"   :make [args]        write the buffer, return at once and run 'makeprg'
"                       as a job; the quickfix list is filled when it ends
"
" In every buffer, or those whose filetype is in g:bgmake_filetypes. Nothing
" jumps and no window opens when it ends, because the cursor may be anywhere
" by then. It says how it went, and :clist has the errors.
"
" :make cannot be pointed at a Vim function, but it can be stopped. It fires
" QuickFixCmdPre and then returns if the autocommand aborted, and interrupt()
" is how an autocommand aborts: CTRL-C with nothing on the screen. So this is
" reached by every :make, typed or from a mapping or a script, which an
" abbreviation is not.
"
" Nothing may print before interrupt(): a message on the screen turns the
" silent stop into "Interrupt: Press ENTER". So the work waits for a timer.
"
" The autocommand cannot see the arguments of :make either. They are read from
" the command line that was typed for it, kept by CmdlineLeave.
"
" See |bgmake|.
if exists('g:loaded_bgmake') || !has('job') || !exists('*interrupt')
  finish
endif
let g:loaded_bgmake = 1

" '*' is every buffer, with a filetype or without.
let g:bgmake_filetypes = get(g:, 'bgmake_filetypes', ['*'])

augroup bgmake
  autocmd!
  autocmd CmdlineLeave : call bgmake#typed()
  " The arguments are taken by every :make, run here or not, so that a typed
  " line is never left over for a later one.
  autocmd QuickFixCmdPre make let s:args = bgmake#args() | if bgmake#wanted()
    \ | call timer_start(0, function('bgmake#make', [s:args])) | call interrupt() | endif
augroup END
