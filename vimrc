set nocompatible
set t_Co=256
set background=light
set termguicolors
filetype plugin on
filetype indent on
syntax on
" noremap <silent> <F2> :let &cc = &cc == '' ? join(range(81,256),",") : '' <CR>
set showcmd
set spelllang=en_us
set backspace=indent,eol,start
set laststatus=2
set statusline=%F
" if !has('win32')
" 	let gitBranch=trim(system("git branch 2> /dev/null | sed -e 's/..//'"))
" 	set statusline=%F\ (%{gitBranch})%=%{strftime('%a\ %b\ %-d\ %-I\:%M\:%S\ %p')}\ 
" 
" 	let timer = timer_start(1000, 'UpdateStatusBar', {'repeat':-1})
" 	function! UpdateStatusBar(timer)
" 		execute 'let &ro = &ro'
" 	endfunction
" endif
" noremap <Up> <Nop>
" noremap <Down> <Nop>
" noremap <Right> <Nop>
" noremap <Left> <Nop>
" set listchars=tab:\ \ ,nbsp:+,space:·,trail:.
" let t:is_transparent = 0
" function! ToggleTransparent()
" 	if t:is_transparent == 0
" 		highlight Normal ctermbg=NONE
" 		highlight StatusLine ctermfg=15 ctermbg=NONE cterm=bold
" 		let t:is_transparent = 1
" 	else
" 		highlight Normal ctermbg=0
" 		highlight StatusLine ctermfg=15 ctermbg=0 cterm=bold
" 		let t:is_transparent = 0
" 	endif
" endfunction
" nnoremap <silent> <F6> :call ToggleTransparent()<CR>
set tabstop=4
set softtabstop=4
set shiftwidth=4
" set autoindent
" set copyindent
set expandtab
set scrolloff=5
set incsearch
set wildmenu
set mouse=
set path+=**
augroup vimrc-incsearch-highlight
    autocmd!
    autocmd CmdlineEnter /,\? :set hlsearch
    autocmd CmdlineLeave /,\? :set nohlsearch
augroup END
let &wildignore = join(map(split(substitute(substitute(
            \ netrw_gitignore#Hide(), '\.\*', '*', 'g'), '\\.', '.', 'g'), ','),
            \ "v:val.','.v:val.'/'"), ',')
set wildignore+=**/venv/**
set wildignore+=**/__pycache__/**
set wildignore+=**/node_modules/**
let g:netrw_keepdir = 0
let g:netrw_banner = 0
let g:netrw_localcopydircmd = 'cp -r'
let g:netrw_liststyle = 1
let g:netrw_sizestyle='h'
let g:netrw_list_hide= netrw_gitignore#Hide() .. '.*\.swp$'
if executable("rg")
    set grepprg=rg\ --vimgrep\ --smart-case
endif
set omnifunc=syntaxcomplete#Complete
set belloff=all
