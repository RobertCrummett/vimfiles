if getline(1) =~# "^#lang sicp$"
    syntax keyword racketSICP cons-stream containedin=ALLBUT,racketComment
    syntax keyword racketSICP stream-null? containedin=ALLBUT,racketComment
    highlight default link racketSICP racketFunc
endif
