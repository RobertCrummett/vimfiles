" Boolean options can be set like this:
set number
" and turned off like this:
set nonumber

" The pattern is :set <name> and :set no<name>
" Boolean options can also be toggled by
" appending an exclamation point
set number!

" By adding a question mark, we can ask
" Vim what the current value of a variable is
set number?
set number!
set number?

" References
" https://learnvimscriptthehardway.stevelosh.com/chapters/02.html
