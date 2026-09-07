if exists('b:current_syntax')
  finish
endif

" Review buffer of :GeoSpellHarvest: "count<Tab>word" lines and # comments.
syntax match geospellComment /^\s*#.*/
syntax match geospellCount   /^\d\+\ze\t/

highlight default link geospellComment Comment
highlight default link geospellCount   Number

let b:current_syntax = 'geospell'
