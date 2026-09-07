" In "for l:index in ...", the bundled syntax lets the Vim9 bare-name match
" (defined later) beat the scoped-variable match, so "l:" is split from the
" name and never gets the vimVarScope colour. A match defined here comes
" last, so it wins at that position.
syn match vimForScopedVar "\<[bwglstav]:\h[a-zA-Z0-9#_]*\>"
  \ contained containedin=vimFor,vimVarList,vim9VariableList
  \ contains=vimVarScope nextgroup=vimSubscript
hi def link vimForScopedVar vimVar
