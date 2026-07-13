if &compatible
  set nocompatible
endif

if has('syntax') && !exists('g:syntax_on')
  syntax on
endif
filetype plugin indent on

set nowrap sidescroll=5

set noerrorbells
set novisualbell
set t_vb=
set belloff=all

set wildmenu
set wildignore+=*.pdf,*.o
set wildignore+=*.obj,*.pdb,*.ilk,*.exe
set wildignore+=*/.git/*,*/.DS_Store

set backspace=eol,start,indent

if has('termguicolors')
  set termguicolors
endif

set timeout timeoutlen=3000 ttimeoutlen=100

colorscheme quiet

augroup colorscheme_modifications
  au!
  " color scheme morning
  au Colorscheme morning highlight Constant ctermfg=201 ctermbg=NONE guifg=#ff00ff guibg=NONE

  " color scheme evening
  au Colorscheme evening highlight Normal ctermbg=0 guibg=#000000
  au Colorscheme evening highlight EndOfBuffer ctermfg=153 ctermbg=0 guifg=#add8e6 guibg=#000000

  " FIXME Current backgorund highlighting for Spell* does not
  " switch when the background option is toggled.

  " color scheme quiet
  " au Colorscheme quiet highlight SpellBad  ctermbg=0 guibg=#000000
  " au Colorscheme quiet highlight SpellCap  ctermbg=0 guibg=#000000
  " au Colorscheme quiet highlight SpellRare ctermbg=0 guibg=#000000
  " au Colorscheme quiet setlocal spell spl=en_us
augroup END

augroup clean_comments
  autocmd!
  autocmd ColorScheme * highlight clear Todo
  autocmd ColorScheme * highlight link Todo Comment
augroup END

" Apply clean comments immediately (in case the colorscheme is already loaded)
highlight clear Todo
highlight link Todo Comment

" NOTE This check is inserted in case that someone (me) sets a color scheme
" before the colorscheme_modifications apply. So this conditional ensures that
" the order of calling colorscheme and defining the autocommand do not matter.
if exists('g:colors_name')
  execute 'colorscheme' g:colors_name
endif

if has('extra_search')
  set hlsearch incsearch
endif
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :noh<C-R>=has('diff')?'<Bar>dif':''<CR><CR><C-L>
endif

set autoindent smarttab expandtab
set formatoptions+=jr/ncq fo-=to textwidth=80 nojoinspaces
nnoremap Q gq

set autoread
augroup updates
  au!
  au FocusGained,BufEnter * silent! checktime
augroup END

set viminfo^=!
if has('mksession')
  set sessionoptions-=options viewoptions-=options
endif

if empty(mapcheck('<C-U>', 'i'))
  inoremap <C-U> <C-G>u<C-U>
endif

if empty(mapcheck('<C-W>', 'i'))
  inoremap <C-W> <C-G>u<C-W>
endif

" This disables netrw
let g:loaded_netrw=1
let g:loaded_netrwPlugin=1

" Remove included files from the search list to speed up insert mode completion
" problems.
"
" FIXME Hangs, sometimes with 'Scanning: <path>' message displayed on repeated
" i_CTRL-X_CTRL-L presses while holding down CTRL key on Win32. There is only
" one other person online who seems to have encountered this bug, but there was
" no progress in solving it so far as I can tell. Upon grepping vim source, I
" can find the location of the 'Scanning: ' message. However, it led me no
" closer to figuring out this issue.
"
" NOTE This behavior does not occur on posix systems. As expected, repeated
" presses of i_CTRL-X_CTRL-L bring in lines below matching line.
"
" NOTE This works on Win32, in the gui editor. So it seems to be a problem with
" vim from the terminal in Win32 only.
set complete-=i foldmethod=manual

if executable('rg')
  set grepformat+=%f:%l:%c:%m grepprg=rg\ --vimgrep\ -uu
endif

if executable('lynx') && !has('win32')
  let g:Openprg='lynx' " Openprg is not working as I expect. Not sure why.
  nn gx :exe '!lynx ' . shellescape(substitute(expand("<cfile>", 1), '#', '%23', 'g'))<CR><CR>
endif

set nrformats-=octal
set nobackup noswapfile

if exists(":DiffOrig") != 2
  com DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | difft | wincmd p | difft
endif

if has("gui_running")
  set guioptions-=T go-=e go-=m go-=r go-=R go-=l go-=L
  set t_Co=256
  if has("gui_win32")
    set guifont=Consolas:h15

    function! s:ChangeFontSize(inc) abort
      let l:font_size = matchstr(&guifont, '\(:h\)\@<=\d\+$')
      let l:new_font_size = ':h' . (l:font_size + a:inc)
      let &guifont = substitute(&guifont, ':h\d\+$', l:new_font_size, '')
    endfunction

    nnoremap <C-ScrollWheelUp>   :call <SID>ChangeFontSize(+1)<CR>
    nnoremap <C-ScrollWheelDown> :call <SID>ChangeFontSize(-1)<CR>
  endif
endif

" Search for text highlighted in visual mode.
vnoremap <silent> * :<C-u>call <SID>VSetSearch()<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call <SID>VSetSearch()<CR>?<C-R>=@/<CR><CR>

function! s:VSetSearch()
  let l:saved_reg = @s
  normal! gv"sy
  let @/ = '\V' . substitute(escape(@s, '/\'), '\n', '\\n', 'g')
  let @s = l:saved_reg
endfunction

augroup restart_editing_in_context
  autocmd!
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
augroup END

" NOTE Move lines.
" Stole from https://github.com/amix/vimrc/blob/master/vimrcs/basic.vim
" These overwrite CTRL-K, which is by default the enter digraph command.
nnoremap <C-j> mz:m+<CR>`z
nnoremap <C-k> mz:m-2<CR>`z
vnoremap <C-j> :m'>+<CR>`<my`>mzgv`yo`z
vnoremap <C-k> :m'<-2<CR>`>my`<mzgv`yo`z

" vim-sexp specific settings.
if !exists('g:sexp_loaded')
  let g:sexp_filetypes = 'clojure,scheme,lisp,timl,fennel,racket'
endif

" augroup custom_highlight_todo_words
"   au!
"   au Syntax * syntax keyword Todo NOTE containedin=.*Comment.*
" augroup END

let maplocalleader = "\\"

function! SynStack()
  if !exists("*synstack")
    return
  endif
  echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc

" function! LispColorscheme()
"   colorscheme quiet
"   hi! racketParen guifg=#22ddaa
" endfunction
