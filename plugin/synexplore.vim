" synexplore: see why text is coloured the way it is, in buffers you can
" search and copy from.
"
"   :SynCursor[!]          what applies to the text under the cursor: the
"                          syntax stack, which item wins, each link chain,
"                          the rule text, and where every piece was set
"                          (! opens it in a buffer instead of echoing)
"   :SynGroup {group}      one highlight group: link chain, colours, source
"   :SynHighlights [pat]   every highlight group (matching pat), with a
"                          coloured sample, its link/attributes, and source
"   :SynRules [group]      the syntax rules active in this buffer (or one
"                          group's), with sources and a precedence primer
"
" "Source" lines say where a group or rule was last set and whether that
" file is yours to edit (vimrc, vimfiles, your colorscheme) or Vim's runtime.
if exists('g:loaded_synexplore')
  finish
endif
let g:loaded_synexplore = 1

" :SynCursor opens a report buffer; :SynCursor! only echoes the stack.
command! -bar -bang                        SynCursor     call synexplore#cursor(!<bang>0)
command! -bar                              SynExplore    call synexplore#cursor(1)
command! -bar -nargs=1 -complete=highlight SynGroup      call synexplore#group(<q-args>)
command! -bar -nargs=? -complete=highlight SynHighlights call synexplore#highlights(<q-args>)
command! -bar -nargs=? -complete=highlight SynRules      call synexplore#rules(<q-args>)
