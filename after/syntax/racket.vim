" display is racketSyntax upstream, next to write and print; it is a function
" like any other, so give it its own group, defined after the runtime file so
" the later keyword wins.
"
" It joins @racketTop rather than using containedin=ALLBUT: that cluster is
" what the racketStruc paren regions contain, so the keyword reaches the
" inside of a form without also being matched inside strings and #| |# blocks.
syntax keyword racketBase display
syntax cluster racketTop add=racketBase

highlight default link racketBase racketFunc
