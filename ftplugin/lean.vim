" Lean 4. The runtime detects *.lean and has nothing else for it, so this is
" the whole filetype plugin and not a layer in after/. See |lean-local|.
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

compiler lean

setlocal commentstring=--\ %s
setlocal comments=s0:/-,mb:\ ,ex:-/,:--
setlocal formatoptions-=t formatoptions-=c

setlocal shiftwidth=2 softtabstop=-1 expandtab

" h' and f'' are identifiers.
setlocal iskeyword+='
setlocal matchpairs+=⟨:⟩,⟦:⟧,«:»,‹:›

" gf on the Foo.Bar.Baz of an import, from the project root or from a
" directory above the buffer.
setlocal suffixesadd=.lean
setlocal include=^\\s*\\%(\\%(public\\\|private\\\|meta\\)\\s\\+\\)*import\\%(\\s\\+all\\)\\?
setlocal includeexpr=tr(v:fname,'.','/')
setlocal path=.,,
if !empty(get(b:, 'lean_root', ''))
  execute 'setlocal path+=' . escape(b:lean_root, ' ,\')
endif

" \to gives →, \all ∀, \a α. The table is in autoload/lean.vim.
if get(g:, 'lean_symbol_maps', 1)
  call lean#map()
endif

" The goal window: asked for by hand, or opened with the first Lean buffer.
" Not from inside the FileType event, where the buffer is still being read.
nnoremap <buffer> <silent> <LocalLeader>g :LeanGoal<CR>
if get(g:, 'lean_goal_auto', 0)
  call timer_start(0, {-> lean#goal#open()})
endif

let b:undo_ftplugin = 'setlocal commentstring< comments< formatoptions< shiftwidth<'
  \ . ' softtabstop< expandtab< iskeyword< matchpairs< suffixesadd< include<'
  \ . ' includeexpr< path< makeprg< errorformat<'
  \ . ' | unlet! b:lean_root | call lean#unmap()'
  \ . ' | silent! nunmap <buffer> <LocalLeader>g'

let &cpo = s:save_cpo
unlet s:save_cpo
