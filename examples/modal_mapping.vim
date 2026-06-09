" A normal mode command can be mapped like this
nmap \ dd
" and a visual mode mapping appears as
vmap \ U

" Insert mode mapping:
imap <c-d> dd
" ... but wait! This simply enters the letters 'dd', 
" as if that is what we wanted to happen. To get into
" normal mode before executing the command,
imap <c-d> <esc>dd
" ... but this leaves us in insert mode. Final version:
imap <c-d> <esc>ddi

" References
" https://learnvimscriptthehardway.stevelosh.com/chapters/04.html
