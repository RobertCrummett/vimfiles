" diredit: edit a directory listing as text; :w applies the changes.
"
"   :Ex [dir]      open a directory (defaults to the current file's)
"   -              open the parent directory of the current file/listing
"
" In a listing, every line is one entry. Rename by editing the name, delete
" with dd, copy with yy/p, move by writing a relative or absolute path, and
" create by adding a line (a trailing / makes a directory). See g? there.
if exists('g:loaded_diredit')
  finish
endif
let g:loaded_diredit = 1

" Ask before applying changes (set to 0 to apply silently).
let g:diredit_confirm = get(g:, 'diredit_confirm', 1)
" Show dotfiles.
let g:diredit_show_hidden = get(g:, 'diredit_show_hidden', 1)
" Show the details column (date, time, size; permissions on Unix).
let g:diredit_details = get(g:, 'diredit_details', 1)

command! -nargs=? -complete=dir Ex      call diredit#open(<q-args>)
command! -nargs=? -complete=dir Explore call diredit#open(<q-args>)

augroup diredit
  autocmd!
  autocmd BufReadCmd  diredit://* call diredit#render()
  autocmd BufWriteCmd diredit://* call diredit#apply()
  " Refresh a listing when coming back to it, unless it has unsaved edits.
  autocmd BufEnter    diredit://* if exists('b:diredit_dir') && !&modified | call diredit#render() | endif
  " Opening a directory (:e ., vim .) lands in a listing instead of an
  " empty buffer.
  autocmd BufEnter    * ++nested call diredit#hijack(expand('<amatch>'))
augroup END

if maparg('-', 'n') ==# ''
  nnoremap <silent> - <Cmd>call diredit#open_parent()<CR>
endif
