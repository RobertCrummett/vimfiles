" Not all options are boolean. Some take values. For instance,
set number
set numberwidth=10
" The first option is boolean. The second
" requires a width be set.

set nonumber
set numberwidth?
" Even though the numbers are no longer displayed,
" the value of number width does not change. If the
" option were retoggled, then we would get a gutter
" ten spaces wide.

set wrap?
set shiftround?
set matchtime?

" We can even set multiple options at once.
set number relativenumber numberwidth=4


" References
" learnvimscriptthehardway
