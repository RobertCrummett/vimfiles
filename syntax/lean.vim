if exists('b:current_syntax')
  finish
endif

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" Lean 4. Vim detects .lean files but ships no syntax for them, so this is the
" whole of it, not a layer on a runtime file. Coloured by colors/custom.vim.

" Word characters for the syntax alone; w and * in the buffer are untouched.
" ' ! and ? end names such as hg.ne' and simp?, and with . a dotted name is one
" word, so that the ext of Complex.ext is not the tactic ext.
syntax iskeyword @,48-57,_,192-255,39,33,63,46

" Block comments nest, and a file can open one anywhere.
syntax sync fromstart

syntax keyword leanTodo TODO FIXME XXX NOTE contained
syntax match leanLineComment /--.*$/ contains=leanTodo,@Spell
" Doc comments, /-- and /-!, are comments too.
syntax region leanComment start=/\/-/ end=/-\// contains=leanComment,leanTodo,@Spell

" The name a declaration introduces, and the name of a namespace or section,
" which end repeats. Lean also lets the letter-like block into names, as in
" foo_ℝ, and \k stops at those, and anything at all between « and ». The class
" keyword comes first in class inductive and class abbrev, so the name may
" still be a keyword away.
syntax match leanDeclName /\%(«[^»]*»\|\k\|[\u2100-\u214f]\)\+/ contained
syntax keyword leanDecl theorem lemma def abbrev instance structure class
  \ inductive coinductive opaque nextgroup=leanDecl,leanDeclName skipwhite
syntax keyword leanSection namespace section end nextgroup=leanDeclName skipwhite

" Where Lean stops checking: a proof left out, a statement taken on trust, a
" definition that need not terminate or is outside the kernel's logic.
syntax keyword leanUnchecked sorry admit stop native_decide unsafe partial
syntax keyword leanUnchecked axiom nextgroup=leanDeclName skipwhite

syntax keyword leanKeyword import module prelude public meta open export hiding
  \ renaming variable universe include omit mutual alias deriving extends where
  \ example macro macro_rules syntax elab elab_rules notation notation3 infix
  \ infixl infixr prefix postfix declare_syntax_cat initialize builtin_initialize
  \ private protected noncomputable nonrec local scoped
syntax keyword leanKeyword fun by do let have show from suffices calc match with
  \ if then else for in unless while return break continue catch finally mut at
  \ using generalizing termination_by decreasing_by haveI letI

syntax keyword leanType Type Sort Prop
syntax keyword leanBoolean True False true false

" Every word that starts with a digit: 2, 1_000, 0x1F, 2.5.
syntax match leanNumber /\k\@1<!\d\k*/ display

" The tactics. Taken from the parser's own table with Mathlib loaded, keeping
" those Mathlib calls at least 10 times and at least as often as it uses the
" word for anything else, with their ! ? and ' forms. That leaves out left,
" right, symm and trans, which are mostly ordinary names, but rfl is kept. have,
" show and let are in the terms as well, so they stay keywords above.
syntax keyword leanTactic
  \ abel abel! abel_nf abel_nf! ac_rfl aesop aesop? aesop_cat aesop_cat?
  \ aesop_mat algebraize all_goals any_goals apply apply? apply_fun
  \ apply_rules assumption assumption' assumption_mod_cast bddDefault
  \ beta_reduce bicategory borelize by_cases by_cases! by_contra
  \ by_contra! calc? case case' cases cases' casesm casesm! cat_disch
  \ cfc_cont_tac cfc_tac cfc_zero_tac change change? choose choose!
  \ classical clear clear! clear_value congr congr! congrm congrm?
  \ constructor constructor! contradiction contrapose contrapose! conv
  \ conv' conv? conv_lhs conv_rhs convert convert! convert_to convert_to!
  \ decide delta dsimp dsimp! dsimp? dsimp?! erw erw? eta_expand exact
  \ exact? exact_mod_cast exacts exfalso ext ext1 fail fapply fconstructor
  \ field_simp filter_upwards fin_cases finiteness finiteness? first focus
  \ fun_prop funext gcongr gcongr? gconvert generalize generalize'
  \ generalize_proofs grind grind? grw have' inclusion inclusion?
  \ induction induction' infer_instance inhabit injection injections
  \ interval_cases intro intros introv isBoundedDefault iterate let' lia
  \ lift linarith linarith! linarith? linarith?! linear_combination
  \ linear_combination' match_scalars measurability measurability!
  \ measurability!? measurability? mfld_set_tac monoidal
  \ monoidal_coherence next nlinarith nlinarith! noncomm_ring
  \ nontriviality norm_cast norm_num norm_num1 nth_grw nth_rewrite nth_rw
  \ obtain omega on_goal positivity pull push push_cast rcases rcongr
  \ refine refine' rename rename' rename_i repeat repeat' replace revert
  \ rfl rfl' rfl_cat rify ring ring! ring1 ring1! ring_nf ring_nf! rintro
  \ rotate_left rsuffices rw rw! rw? rw?? rw_mod_cast rwa set set! simp
  \ simp! simp? simp?! simp_all simp_all! simp_all? simp_all?! simp_rw
  \ simpa simpa! simpa? simpa?! skip slice_lhs slice_rhs solve_by_elim
  \ specialize split split_ifs subsingleton subst subst_hom_lift
  \ subst_vars swap tauto tauto_set tfae_finish tfae_have toFinite_tac
  \ to_encard_tac trace try try? unfold unreachable! use use! valid
  \ volume_tac with_reducible with_reducible_and_instances
  \ with_unfolding_all wlog wlog! zify

" A goal left to fill in: ?_ and ?name.
syntax match leanHole /\k\@1<!?\k\+/ display

" The logic of a statement and the shape of a proof: the binders, the
" connectives, the arrows, the brackets of an anonymous constructor, the focus
" dot and <;>. None of them can be part of a name, not even the Greek ones.
" Arithmetic and relations stay plain, spelled in Unicode or not: an accent on
" = and <= as well would colour half of every statement.
syntax match leanNotation /[∀∃∑∏∫⋃⋂⨆⨅]/ display
syntax match leanNotation /[λΠΣ→←↔↦]/ display
syntax match leanNotation /[∧∨¬⊢⟨⟩·]/ display
syntax match leanNotation "<->\|<-\|->\|/\\\|\\/\|<;>" display

" @[simp], attribute [local simp], with any brackets inside them. Strings and
" comments may hold a lone bracket, as in @[to_dual /-- the interval $[a, b)$ -/],
" and don't count. The matchgroup keeps the [ of @[ from opening a list of its
" own, whose ] would then close the wrong one.
syntax region leanAttribute matchgroup=leanAttribute start=/@\[/ end=/\]/
  \ contains=leanAttributeList,leanString,leanComment
syntax region leanAttributeList start=/\[/ end=/\]/ contained
  \ contains=leanAttributeList,leanString,leanComment
syntax keyword leanKeyword attribute nextgroup=leanAttributeList skipwhite

syntax keyword leanKeyword set_option unset_option nextgroup=leanOption skipwhite
syntax match leanOption /\k\+/ contained

" #check, #eval!, #print axioms. Only as the first thing on a line: #s can also
" be the card of a Finset.
syntax match leanCommand /^\s*\zs#\k\+/

syntax match leanEscape /\\\%(x\x\x\|u\x\{4}\|[\\"'nrt]\|$\)/ contained
" \Z: notation can be a lone combining accent, and in "<accent>" the accent joins
" the opening quote, which then only matches with the composing mark ignored.
" Without it the closing quote opens a string that runs to the end of the file.
syntax region leanString start=/\Z"/ skip=/\\./ end=/\Z"/ contains=leanEscape,@Spell
syntax region leanRawString start=/\Z\k\@1<!r\z(#*\)"/ end=/\Z"\z1/ contains=@Spell
" s!"text {x}" and its m! and f! kin: the braces hold a term.
syntax region leanString start=/\Z\k\@1<![smf]!"/ skip=/\\./ end=/\Z"/
  \ contains=leanEscape,leanInterpolation
syntax region leanInterpolation matchgroup=leanInterpolationDelim start=/{/ end=/}/
  \ contained contains=TOP
" After a word, ' belongs to the name: h' and hg.ne' open no character.
syntax match leanChar /\k\@1<!'\%(\\\%(x\x\x\|u\x\{4}\|.\)\|[^\\']\)'/ contains=leanEscape

highlight default link leanComment       Comment
highlight default link leanLineComment   leanComment
highlight default link leanTodo          Todo
highlight default link leanDecl          Keyword
highlight default link leanSection       Keyword
highlight default link leanKeyword       Keyword
highlight default link leanDeclName      Function
highlight default link leanTactic        Function
highlight default link leanUnchecked     Todo
highlight default link leanType          Type
highlight default link leanBoolean       Boolean
highlight default link leanNumber        Number
highlight default link leanHole          Special
highlight default link leanNotation      Special
highlight default link leanAttribute     PreProc
highlight default link leanAttributeList leanAttribute
highlight default link leanOption        PreProc
highlight default link leanCommand       PreProc
highlight default link leanEscape        SpecialChar
highlight default link leanInterpolationDelim SpecialChar
highlight default link leanString        String
highlight default link leanRawString     leanString
highlight default link leanChar          Character

let b:current_syntax = 'lean'

let &cpo = s:save_cpo
unlet s:save_cpo
