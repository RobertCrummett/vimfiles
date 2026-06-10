syntax keyword racketBase newline containedin=ALLBUT,racketComment
highlight default link racketBase racketFunc

if getline(1) =~# "^#lang sicp$"
    syntax keyword SICPFunc cons-stream containedin=ALLBUT,racketComment
    syntax keyword SICPFunc stream-null? containedin=ALLBUT,racketComment
    highlight default link SICPFunc racketFunc
endif
