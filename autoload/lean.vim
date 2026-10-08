" Lean 4: the symbols typed with a backslash, and the repair of what :make
" puts in the quickfix list. See |lean-local|.
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" Name -> symbol, the names Lean's own editor support uses, so \to and \all
" mean here what they mean in VS Code. None of the names is a string escape
" (\n \t \r \x \u \\ \" \'), so "a\n" can still be typed; that is why × is
" \times and not \x, and ↑ is \up and not \u.
let s:symbols = {
  \ 'to': '→', '->': '→', 'l': '←', '<-': '←', 'iff': '↔', '<->': '↔', 'lr': '↔',
  \ '=>': '⇒', 'mapsto': '↦', 'up': '↑', 'dn': '↓',
  \ 'fun': 'λ', 'lam': 'λ',
  \ 'all': '∀', 'forall': '∀', 'ex': '∃', 'exists': '∃',
  \ 'not': '¬', 'neg': '¬', 'and': '∧', 'or': '∨', 'top': '⊤', 'bot': '⊥', '|-': '⊢',
  \ 'ne': '≠', 'le': '≤', 'ge': '≥', '==': '≡', 'approx': '≈', 'simeq': '≃', 'cong': '≅',
  \ '<': '⟨', '>': '⟩', '<<': '«', '>>': '»', '[[': '⟦', ']]': '⟧', 'f<': '‹', 'f>': '›',
  \ '.': '·', 'tr': '▸', 'comp': '∘', 'o': '∘', 'times': '×', '|': '∣', 'inv': '⁻¹',
  \ 'in': '∈', 'notin': '∉', 'sub': '⊆', 'ssub': '⊂', 'sup': '⊇', 'ssup': '⊃',
  \ 'un': '∪', 'cup': '∪', 'i': '∩', 'cap': '∩', 'empty': '∅',
  \ 'lub': '⊔', 'glb': '⊓', 'oplus': '⊕', 'otimes': '⊗',
  \ 'sum': '∑', 'prod': '∏', 'infty': '∞', 'partial': '∂', 'sqrt': '√',
  \ 'N': 'ℕ', 'Z': 'ℤ', 'Q': 'ℚ', 'R': 'ℝ', 'C': 'ℂ',
  \ 'a': 'α', 'b': 'β', 'g': 'γ',
  \ 'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε', 'zeta': 'ζ',
  \ 'eta': 'η', 'theta': 'θ', 'iota': 'ι', 'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ',
  \ 'nu': 'ν', 'xi': 'ξ', 'pi': 'π', 'rho': 'ρ', 'sigma': 'σ', 'tau': 'τ',
  \ 'phi': 'φ', 'chi': 'χ', 'psi': 'ψ', 'omega': 'ω',
  \ 'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Pi': 'Π', 'Sigma': 'Σ',
  \ 'Phi': 'Φ', 'Psi': 'Ψ', 'Omega': 'Ω',
  \ '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  \ '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  \ }

" The table in use: the one above with g:lean_symbols laid over it. An empty
" symbol there takes a name out.
function! lean#symbols() abort
  return filter(extend(copy(s:symbols), get(g:, 'lean_symbols', {})), '!empty(v:val)')
endfunction

" A name as the left side of a mapping.
function! s:lhs(name) abort
  let l:lhs = get(g:, 'lean_symbol_leader', '\') . a:name
  let l:lhs = substitute(l:lhs, '<', '<lt>', 'g')
  let l:lhs = substitute(l:lhs, '\\', '<Bslash>', 'g')
  let l:lhs = substitute(l:lhs, '|', '<Bar>', 'g')
  return substitute(l:lhs, ' ', '<Space>', 'g')
endfunction

" Insert mode mappings for the current buffer, one per name.
function! lean#map() abort
  let b:lean_mapped = []
  for [l:name, l:symbol] in items(lean#symbols())
    let l:lhs = s:lhs(l:name)
    execute 'inoremap <buffer>' l:lhs substitute(l:symbol, '|', '<Bar>', 'g')
    call add(b:lean_mapped, l:lhs)
  endfor
endfunction

function! lean#unmap() abort
  for l:lhs in get(b:, 'lean_mapped', [])
    execute 'silent! iunmap <buffer>' l:lhs
  endfor
  unlet! b:lean_mapped
endfunction

" :LeanSymbols, the table in a scratch window, sorted by symbol so the names
" for one symbol stand together.
function! lean#list() abort
  let l:leader = get(g:, 'lean_symbol_leader', '\')
  let l:names = {}
  for [l:name, l:symbol] in items(lean#symbols())
    let l:names[l:symbol] = add(get(l:names, l:symbol, []), l:leader . l:name)
  endfor
  let l:lines = map(sort(keys(l:names)),
    \ 'v:val . "\t" . join(sort(l:names[v:val]), "  ")')
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile nospell
  call setline(1, l:lines)
  setlocal nomodifiable
endfunction

" Called after :make (a:loclist 0) or :lmake (1) in a Lean buffer, before
" Vim jumps to the first error. Two things 'errorformat' cannot do:
"
" Lean counts columns from 0 and in characters, Vim from 1 and in bytes, so
" the column after "(h : α → β)" would land in the middle of a character.
"
" Lake names an imported file that fails to build by its path from the
" project root, which is not where :make ran (the directory of the buffer),
" so Vim has attached the entry to a file that does not exist.
function! lean#quickfix(loclist) abort
  let l:items = a:loclist ? getloclist(0) : getqflist()
  " Replacing the items puts the list back on its first line, and :make
  " would then jump there instead of to the first error.
  let l:idx = (a:loclist ? getloclist(0, {'idx': 0}) : getqflist({'idx': 0})).idx
  let l:root = get(b:, 'lean_root', '')
  let l:stale = {}
  for l:item in l:items
    if !l:item.valid || l:item.bufnr == 0
      continue
    endif
    let l:name = bufname(l:item.bufnr)
    if !filereadable(l:name) && !empty(l:root) && filereadable(l:root . '/' . l:name)
      let l:stale[l:item.bufnr] = 1
      let l:item.bufnr = bufadd(l:root . '/' . l:name)
    endif
    if l:item.lnum == 0
      continue
    endif
    call bufload(l:item.bufnr)
    let l:text = get(getbufline(l:item.bufnr, l:item.lnum), 0, '')
    let l:byte = byteidx(l:text, l:item.col)
    let l:item.col = (l:byte < 0 ? strlen(l:text) : l:byte) + 1
    let l:item.vcol = 0
  endfor
  if a:loclist
    call setloclist(0, [], 'r', {'items': l:items, 'idx': l:idx})
  else
    call setqflist([], 'r', {'items': l:items, 'idx': l:idx})
  endif
  for l:bufnr in keys(l:stale)
    execute 'silent! bwipeout' l:bufnr
  endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
