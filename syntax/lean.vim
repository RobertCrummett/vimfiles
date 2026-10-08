" Lean 4, kept simple: comments, text literals, the keywords of commands and
" terms, the name a declaration introduces, attributes and # commands.
" Tactics and library names are left alone. Coloured by colors/custom.vim.
if exists('b:current_syntax')
  finish
endif
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

syn case match
" h' is one identifier, so the have of have' is not a keyword.
syn iskeyword @,48-57,_,',192-255

" Comments nest, and a doc comment (/-- -/, /-! -/) is a comment.
syn keyword leanTodo TODO FIXME XXX NOTE contained
syn match  leanComment "--.*$" contains=leanTodo,@Spell
syn region leanBlockComment start="/-" end="-/" contains=leanBlockComment,leanTodo,@Spell

" "text", r"raw" and r#"raw"#, and s!"interpolated {x}" with its m! and f!
" kin, where the braces hold a term.
syn match  leanEscape +\\\%(x\x\x\|u{\x\+}\|$\|.\)+ contained
syn region leanString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=leanEscape,@Spell
syn region leanString start=+\<r\z(#*\)"+ end=+"\z1+ contains=@Spell
syn region leanString start=+\<[smf]!"+ skip=+\\\\\|\\"+ end=+"+ contains=leanEscape,leanInterpolation
syn region leanInterpolation matchgroup=leanInterpolationDelim start="{" end="}" contained contains=TOP

" 'a' and '\n'. Something has to come before the quote that an identifier
" cannot end in, or the quotes of (f' x') would be a character.
syn match leanChar +\%(^\|[[:space:](\[{,⟨]\)\@1<='\%(\\\%(x\x\x\|u{\x\+}\|.\)\|[^\\']\)'+ contains=leanEscape

syn match leanNumber "\<\d\+\%(\.\d\+\)\?\%([eE][-+]\?\d\+\)\?\>"
syn match leanNumber "\<0[xX]\x\+\>"
syn match leanNumber "\<0[bB][01]\+\>"
syn match leanNumber "\<0[oO]\o\+\>"

" The name after def, theorem and the like. An instance may have none
" (instance : Inhabited Nat), which is why a name cannot start with a
" bracket or a colon, and "class inductive" has one keyword more to go.
syn keyword leanDeclaration def theorem lemma abbrev axiom opaque instance
  \ structure inductive class nextgroup=leanDeclarationName skipwhite
syn match leanDeclarationName "\%(inductive\>\)\@!\%(«[^»]*»\|[^[:space:](){}\[\]⦃⦄:,;«]\)\+"
  \ contained

syn keyword leanCommand example namespace section end open export import
  \ module variable universe set_option attribute mutual deriving
  \ notation infix infixl infixr prefix postfix macro macro_rules syntax
  \ elab elab_rules declare_syntax_cat initialize builtin_initialize
  \ omit include
syn keyword leanModifier private protected public meta noncomputable partial
  \ unsafe nonrec local scoped
syn keyword leanKeyword fun let have show from suffices by at calc using
  \ if then else match with do return for in while unless try catch
  \ finally throw break continue where mut extends
  \ termination_by decreasing_by
syn keyword leanSort Type Prop Sort

" The hole in a proof: where Lean stops checking.
syn keyword leanSorry sorry admit

" #eval, #check, #print: commands that only report.
syn match leanHashCommand "#\a\w*[!?]\?"

" @[simp, inline]
syn region leanAttribute start="@\[" end="\]" oneline

syn sync minlines=300

hi def link leanTodo               Todo
hi def link leanComment            Comment
hi def link leanBlockComment       Comment
hi def link leanString             String
hi def link leanChar               Character
hi def link leanEscape             SpecialChar
hi def link leanInterpolationDelim SpecialChar
hi def link leanNumber             Number
hi def link leanDeclaration        Keyword
hi def link leanDeclarationName    Function
hi def link leanCommand            Keyword
hi def link leanModifier           StorageClass
hi def link leanKeyword            Keyword
hi def link leanSort               Type
hi def link leanSorry              Error
hi def link leanHashCommand        PreProc
hi def link leanAttribute          PreProc

let b:current_syntax = 'lean'

let &cpo = s:save_cpo
unlet s:save_cpo
