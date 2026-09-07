if exists('b:current_syntax')
  finish
endif

" Report headings and the winning stack item.
syntax match synexploreTitle   /\%1l.*/
syntax match synexploreItem    /^\d\+\. \S\+/ " contains=synexploreItemNum
" syntax match synexploreItemNum /^\d\+\./ contained
syntax match synexploreApplies /<== applies/

" Labels that start a line ("link chain:", "on screen:", "set from:", ...).
syntax match synexploreLabel   /^\s*\%(link chain\|on screen\|set from\|set by\|rule from\|Colour on screen comes from\|Window matches[^:]*\|Concealed here\|Columns\|Rule \S\+\|Highlight group \S\+\)\ze:\?/

" Where something was set: the path is dim, the owner tag says whether it
" is yours to edit.
syntax match synexploreSource  /\%(\%(set\|rule\) from: \)\@<=\S.\{-}\ze\s\+\[/ contains=synexploreLine
syntax match synexploreLine    /\<line \d\+/ contained
syntax match synexploreYours   /\[\%(your\|a plugin\)[^\]]*\]/
syntax match synexploreRuntime /\[system runtime[^\]]*\]/
syntax match synexploreBuiltin /Vim built-in default/

" Arrows in link chains and the marker for the SynHighlights owner column.
syntax match synexploreArrow   / -> /
syntax match synexploreOwner   /\[\%(yours\|runtime\|default\|other\)\]$/

highlight default link synexploreTitle   Title
" highlight default link synexploreItemNum Number
highlight default link synexploreApplies WarningMsg
highlight default link synexploreLabel   Statement
highlight default link synexploreSource  Comment
highlight default link synexploreLine    Number
highlight default link synexploreYours   Special
highlight default link synexploreRuntime Comment
highlight default link synexploreBuiltin Comment
highlight default link synexploreArrow   Delimiter
highlight default link synexploreOwner   Special

let b:current_syntax = 'synexplore'
