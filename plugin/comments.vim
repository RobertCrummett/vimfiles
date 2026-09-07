if exists('g:plugin_comments')
  finish
endif
let g:plugin_comments = v:true

" Line-comment leaders by filetype. Entries here win over 'commentstring';
" a buffer can override both with b:comment_leader. Filetypes whose only
" comment syntax is a block (css, html, xml, markdown, ocaml) are not listed,
" and the plugin says so when asked to comment them.
" Comments placed into this map should be unescaped string literals.
let s:leaders = {}
let s:leaders['//'] = ['c', 'cpp', 'objc', 'objcpp', 'cuda', 'arduino', 'rust', 'zig', 'go', 'd',
  \ 'java', 'kotlin', 'scala', 'groovy', 'cs', 'fsharp', 'swift', 'dart', 'haxe',
  \ 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'jsonc', 'json5', 'jsonnet',
  \ 'php', 'pascal', 'delphi', 'glsl', 'hlsl', 'wgsl', 'metal', 'proto', 'solidity', 'dot',
  \ 'verilog', 'systemverilog', 'scss', 'sass', 'less', 'stylus', 'typst', 'asy', 'processing']
let s:leaders['#'] = ['python', 'pyrex', 'sh', 'bash', 'zsh', 'csh', 'tcsh', 'fish', 'nu', 'ps1',
  \ 'perl', 'ruby', 'crystal', 'elixir', 'nim', 'coffee', 'r', 'julia', 'tcl', 'awk', 'sed',
  \ 'yaml', 'toml', 'make', 'cmake', 'dockerfile', 'conf', 'config', 'cfg', 'gitconfig', 'gitcommit',
  \ 'gitrebase', 'gitignore', 'tmux', 'nginx', 'apache', 'sshconfig', 'terraform', 'hcl', 'nix',
  \ 'graphql', 'gnuplot', 'desktop', 'readline', 'dircolors', 'crontab', 'fstab', 'sudoers',
  \ 'requirements', 'just', 'snakemake', 'muttrc', 'pkgbuild', 'debsources']
let s:leaders['--'] = ['lua', 'haskell', 'sql', 'plsql', 'mysql', 'ada', 'vhdl', 'elm', 'purescript',
  \ 'agda', 'idris', 'eiffel', 'applescript']
let s:leaders['%'] = ['matlab', 'octave', 'tex', 'plaintex', 'bibtex', 'context', 'erlang', 'prolog',
  \ 'postscript']
let s:leaders[';;'] = ['racket', 'scheme', 'lisp', 'clojure', 'fennel']
let s:leaders[';'] = ['ini', 'dosini', 'asm', 'nasm', 'masm', 'fasm', 'autohotkey', 'autoit']
let s:leaders['"'] = ['vim']
let s:leaders["'"] = ['vb', 'vbnet', 'basic', 'freebasic']
let s:leaders['!'] = ['fortran', 'xdefaults']
let s:leaders['REM'] = ['dosbatch']

let g:comment_map = get(g:, 'comment_map', {})
for [s:leader, s:fts] in items(s:leaders)
  for s:ft in s:fts
    if !has_key(g:comment_map, s:ft)
      let g:comment_map[s:ft] = s:leader
    endif
  endfor
endfor
unlet s:leaders s:leader s:fts s:ft

" Resolve the comment leader for the current buffer, or '' if none.
" b:comment_leader wins; then dotted filetypes (c.doxygen) are tried
" component by component; then 'commentstring' is used when it describes a
" line comment ("// %s").
function! s:Leader() abort
  if exists('b:comment_leader')
    return b:comment_leader
  endif
  for l:ft in split(&filetype, '\.')
    if has_key(g:comment_map, l:ft)
      return g:comment_map[l:ft]
    endif
  endfor
  let l:leader = matchstr(&commentstring, '^\s*\zs.\{-}\ze\s*%s\s*$')
  return l:leader
endfunction

function! s:IsBlank(line) abort
  return a:line =~# '^\s*$'
endfunction

" True if the line's first non-blank text starts with the leader.
function! s:IsCommented(line, leader) abort
  let l:text = substitute(a:line, '^\s*', '', '')
  return strpart(l:text, 0, len(a:leader)) ==# a:leader
endfunction

function! s:ProcessCommentRange(start_line, end_line) abort
  let l:leader = s:Leader()
  if empty(l:leader)
    echohl WarningMsg
    echom 'No line comment leader for filetype `' . &filetype
      \ . '`; add it to g:comment_map'
    echohl None
    return
  endif
  let l:leader_len = len(l:leader)

  " Non-blank lines in the range. Blank lines are never touched.
  let l:lnums = filter(range(a:start_line, a:end_line),
    \ '!s:IsBlank(getline(v:val))')
  if empty(l:lnums)
    return
  endif

  " Uncomment only when every non-blank line is commented; otherwise comment
  " everything, so a mixed block never gets a second leader.
  let l:all_commented = v:true
  for l:lnum in l:lnums
    if !s:IsCommented(getline(l:lnum), l:leader)
      let l:all_commented = v:false
      break
    endif
  endfor

  " Shallowest indentation in the range: the leader goes there so a
  " commented block lines up. Lines indented less than that keep their own.
  let l:base_indent = ''
  let l:base_width = -1
  for l:lnum in l:lnums
    let l:indent = matchstr(getline(l:lnum), '^\s*')
    let l:width = strdisplaywidth(l:indent)
    if l:base_width < 0 || l:width < l:base_width
      let l:base_indent = l:indent
      let l:base_width = l:width
    endif
  endfor

  let l:view = winsaveview()
  for l:lnum in l:lnums
    let l:line = getline(l:lnum)
    let l:indent = matchstr(l:line, '^\s*')
    let l:text = strpart(l:line, len(l:indent))

    if l:all_commented
      let l:text = strpart(l:text, l:leader_len)
      " Drop the single space we insert when commenting.
      if l:text[0] ==# ' '
        let l:text = strpart(l:text, 1)
      endif
      call setline(l:lnum, l:indent . l:text)
    elseif strpart(l:line, 0, len(l:base_indent)) ==# l:base_indent
      let l:rest = strpart(l:line, len(l:base_indent))
      call setline(l:lnum, l:base_indent . l:leader . ' ' . l:rest)
    else
      call setline(l:lnum, l:indent . l:leader . ' ' . l:text)
    endif
  endfor
  call winrestview(l:view)
endfunction

" Operator function. Works linewise whatever the motion or Visual mode was,
" so gc works with any motion, gcc/3gcc on lines, and . repeats all of them.
function! s:CommentOperator(type) abort
  call s:ProcessCommentRange(line("'["), line("']"))
endfunction

" Set 'operatorfunc' from an <expr> mapping so a count typed before the
" mapping still reaches g@ (a ":set" in the rhs would receive it as a range).
function! s:SetOperator() abort
  let &operatorfunc = expand('<SID>') . 'CommentOperator'
  return ''
endfunction

nnoremap <silent> <expr> gc  <SID>SetOperator() . 'g@'
nnoremap <silent> <expr> gcc <SID>SetOperator() . 'g@_'
xnoremap <silent> <expr> gc  <SID>SetOperator() . 'g@'
