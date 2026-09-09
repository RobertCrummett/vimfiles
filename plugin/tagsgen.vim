" tagsgen: write a tags file with Vim alone, no ctags needed.
"
"   :MakeTags [dir]     scan dir (default: current directory) recursively
"                       and write dir/tags
"
" Definitions are found with the regexes in g:tagsgen_patterns, keyed by
" filetype; extensions map to filetypes through g:tagsgen_filetypes. Both
" can be extended from the vimrc before this plugin loads, or edited here.
if exists('g:loaded_tagsgen')
  finish
endif
let g:loaded_tagsgen = 1

command! -bar -nargs=? -complete=dir MakeTags call tagsgen#make(<q-args>)

" Directory names that are never descended into.
let g:tagsgen_exclude = get(g:, 'tagsgen_exclude',
  \ ['.git', '.hg', '.svn', 'node_modules', 'target', 'build', '__pycache__', '.cache'])

" Files larger than this (bytes) are skipped.
let g:tagsgen_max_size = get(g:, 'tagsgen_max_size', 2 * 1024 * 1024)

" Extension -> filetype.
let s:filetypes = {
  \ 'c': 'c', 'h': 'c',
  \ 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
  \ 'rs': 'rust', 'py': 'python', 'go': 'go', 'js': 'javascript', 'ts': 'javascript',
  \ 'lua': 'lua', 'vim': 'vim', 'sh': 'sh', 'bash': 'sh', 'ps1': 'ps1',
  \ 'bat': 'dosbatch', 'cmd': 'dosbatch', 'm': 'matlab',
  \ 'scm': 'scheme', 'ss': 'scheme', 'rkt': 'racket', 'lisp': 'lisp', 'lsp': 'lisp', 'el': 'lisp',
  \ 'typ': 'typst', 'tex': 'tex', 'sty': 'tex', 'md': 'markdown',
  \ }
let g:tagsgen_filetypes = extend(s:filetypes, get(g:, 'tagsgen_filetypes', {}))

" Filetype -> list of [pattern, kind]. The pattern must isolate the tag
" name with \zs and \ze; every pattern runs over all lines of a file in one
" C-speed matchstrlist() call, so there is no cheaper prefilter to add. (A
" third list element is tolerated and ignored.) Kinds follow ctags:
" f function, c class, s struct, t typedef, d macro, v variable,
" m macro/command, l label, a autocommand group, h heading.
let s:c_ident = '[A-Za-z_][A-Za-z0-9_]*'
" A statement, not a definition: the line ends in a semicolon.
let s:not_stmt = '^\%(.*;\s*$\)\@!'
" Words that are followed by a parenthesis without naming a function.
let s:not_kw = '\%(\%(if\|for\|while\|switch\|return\|sizeof\|else\|do\|case\|defined'
  \ . '\|throw\|catch\|new\|delete\|operator\|alignof\|alignas\|decltype\|typeid\|noexcept'
  \ . '\|constexpr\|co_await\|co_return\|co_yield\|static_assert\|typeof\)\>\)\@!'
let s:c_quals = '\%(\%(static\|inline\|extern\|const\|unsigned\|signed\|struct\|enum\|union\|class\|virtual\|explicit\|constexpr\|friend\|template\s*<[^>]*>\)\s\+\)*'
" A type as it appears before a function name: int, ns::T, std::vector<int>.
let s:c_type = '\%(' . s:c_ident . '\s*::\s*\)*' . s:c_ident . '\%(\s*<[^<>]*>\)\?'
" The end of a definition's parameter list, as opposed to a call broken
" over several lines: the parentheses close on this line and a body or
" initialiser list follows.
let s:c_params = '([^;]*)\s*\%(const\s*\)\?\%(noexcept\s*\)\?\%(override\s*\)\?\%({\|:\)'
let s:patterns = {}
let s:patterns.c = [
  \ ['^\s*#\s*define\s\+\zs' . s:c_ident, 'd'],
  \ ['^\s*\%(typedef\s\+\)\?\%(enum\s\+\%(class\|struct\)\|struct\|union\|enum\|class\)\s\+\zs' . s:c_ident . '\ze\s*\%({\|$\|:\)', 's'],
  \ ['^\s*typedef\s.*\<\zs' . s:c_ident . '\ze\s*\%(\[[0-9]*\]\)\?\s*;\s*$', 't'],
  \ ['^}\s*\zs' . s:c_ident . '\ze\s*;\s*$', 't'],
  \ ['^\zs' . s:not_kw . s:c_ident . '\ze\s*(\%(\s*\*\)\@!\%(.*;\s*$\)\@!', 'f'],
  \ ['\%#=1' . s:not_stmt . '\s*' . s:not_kw . s:c_quals . s:c_type . '[ \t*&]\+\%(' . s:c_ident . '\s*::\s*\)*'
  \   . s:not_kw . '\zs\~\?' . s:c_ident . '\ze\s*(', 'f'],
  \ ]
" \%#=1 on the general function pattern picks the backtracking engine: on
" 30000 lines of C it took 0.04 s there against 0.2-0.7 s when Vim chose
" the NFA engine for it, the lookaheads being what the NFA engine handles
" badly. The pattern is anchored and its repeats do not overlap, so the
" backtracking engine has nothing to blow up on.
" C++ adds definitions with no return type: constructors and destructors,
" scoped (Class::method) at column 0 or inline inside a class body.
let s:patterns.cpp = s:patterns.c + [
  \ ['^\s*\%(' . s:c_ident . '\s*::\s*\)\+\zs\~\?' . s:c_ident . '\ze\s*' . s:c_params, 'f'],
  \ ['^\s\+\%(\%(explicit\|virtual\|inline\|constexpr\)\s\+\)*\zs\~\?[A-Z][A-Za-z0-9_]*\ze\s*' . s:c_params, 'f'],
  \ ]

" Lines to ignore entirely, per filetype (comments, mostly).
let g:tagsgen_skip = extend({
  \ 'c': '^\s*\%(//\|/\*\|\*\)',
  \ 'cpp': '^\s*\%(//\|/\*\|\*\)',
  \ 'rust': '^\s*//',
  \ 'go': '^\s*//',
  \ 'javascript': '^\s*\%(//\|/\*\|\*\)',
  \ }, get(g:, 'tagsgen_skip', {}))
let s:patterns.rust = [
  \ ['^\s*\%(pub\%(([^)]*)\)\?\s\+\)\?\%(async\s\+\|unsafe\s\+\|const\s\+\|extern\s\+"[^"]*"\s\+\)*fn\s\+\zs' . s:c_ident, 'f'],
  \ ['^\s*\%(pub\%(([^)]*)\)\?\s\+\)\?\%(struct\|enum\|union\|trait\|type\|mod\)\s\+\zs' . s:c_ident, 's'],
  \ ['^\s*\%(pub\%(([^)]*)\)\?\s\+\)\?\%(const\|static\)\s\+\%(mut\s\+\)\?\zs' . s:c_ident, 'v'],
  \ ['^\s*macro_rules!\s\+\zs' . s:c_ident, 'd'],
  \ ]
let s:patterns.python = [
  \ ['^\s*\%(async\s\+\)\?def\s\+\zs' . s:c_ident, 'f'],
  \ ['^\s*class\s\+\zs' . s:c_ident, 'c'],
  \ ['^\zs' . s:c_ident . '\ze\s*\%(:\s*\S\+\s*\)\?=[^=]', 'v'],
  \ ]
let s:patterns.go = [
  \ ['^func\s\+\%((\s*\w\+\s\+\*\?\w\+\s*)\s\+\)\?\zs' . s:c_ident, 'f'],
  \ ['^type\s\+\zs' . s:c_ident, 't'],
  \ ]
let s:js_not_kw = '\%(\%(if\|for\|while\|switch\|return\|catch\|function\|else\|do\|await\|yield\|typeof\|new\|super\)\>\)\@!'
let s:patterns.javascript = [
  \ ['^\s*\%(export\s\+\)\?\%(default\s\+\)\?\%(async\s\+\)\?function\s\+\zs' . s:c_ident, 'f'],
  \ ['^\s*\%(export\s\+\)\?class\s\+\zs' . s:c_ident, 'c'],
  \ ['^\s*\%(export\s\+\)\?\%(const\|let\|var\)\s\+\zs' . s:c_ident . '\ze\s*=', 'v'],
  \ ['^\s\+\%(\%(static\|async\|get\|set\)\s\+\)*' . s:js_not_kw . '\zs' . s:c_ident
  \   . '\ze\s*([^()]*)\s*\%(:\s*[^{]\{-}\)\?{', 'f'],
  \ ]
let s:patterns.lua = [
  \ ['^\s*\%(local\s\+\)\?function\s\+\zs[A-Za-z_][A-Za-z0-9_.:]*', 'f'],
  \ ['^\s*\%(local\s\+\)\?\zs[A-Za-z_][A-Za-z0-9_.]*\ze\s*=\s*function\>', 'f'],
  \ ]
let s:patterns.vim = [
  \ ['^\s*fu\%[nction]!\?\s\+\%(<[sS][iI][dD]>\|[sgl]:\)\?\zs[A-Za-z_][A-Za-z0-9_#.]*', 'f'],
  \ ['^\s*\%(export\s\+\)\?def!\?\s\+\%([sg]:\)\?\zs[A-Za-z_][A-Za-z0-9_#.]*', 'f'],
  \ ['^\s*com\%[mand]!\?\s\+\%(-\S\+\s\+\)*\zs[A-Z][A-Za-z0-9_]*', 'm'],
  \ ['^\s*aug\%[roup]\s\+\zs\%(END\>\)\@!\S\+', 'a'],
  \ ['^\s*let\s\+g:\zs[A-Za-z_][A-Za-z0-9_#]*', 'v'],
  \ ]
let s:patterns.sh = [
  \ ['^\s*\%(function\s\+\)\?\zs[A-Za-z_][A-Za-z0-9_-]*\ze\s*()', 'f'],
  \ ['^\s*function\s\+\zs[A-Za-z_][A-Za-z0-9_-]*\ze\s*\%({\|$\)', 'f'],
  \ ]
let s:patterns.ps1 = [
  \ ['^\s*\%(function\|filter\|workflow\)\s\+\%(global:\|script:\)\?\zs[A-Za-z_][A-Za-z0-9_-]*', 'f'],
  \ ['^\s*class\s\+\zs' . s:c_ident, 'c'],
  \ ]
let s:patterns.dosbatch = [
  \ ['^\s*:\zs[A-Za-z_][A-Za-z0-9_-]*', 'l'],
  \ ]
let s:patterns.matlab = [
  \ ['^\s*function\s\+\%([^=]*=\s*\)\?\zs' . s:c_ident, 'f'],
  \ ['^\s*classdef\s\+\zs' . s:c_ident, 'c'],
  \ ]
let s:lisp_name = '[^[:space:]()]\+'
let s:patterns.scheme = [
  \ ['^\s*(define\%(-syntax\|-values\)\?\s\+(\?\zs' . s:lisp_name, 'f'],
  \ ['^\s*(define-\%(record-type\|struct\)\s\+(\?\zs' . s:lisp_name, 's'],
  \ ]
let s:patterns.racket = s:patterns.scheme + [
  \ ['^\s*(struct\s\+\zs' . s:lisp_name, 's'],
  \ ]
let s:patterns.lisp = [
  \ ['^\s*(def\%(un\|macro\|generic\|method\)\s\+\zs' . s:lisp_name, 'f'],
  \ ['^\s*(def\%(var\|parameter\|constant\)\s\+\zs' . s:lisp_name, 'v'],
  \ ['^\s*(def\%(struct\|class\)\s\+(\?\zs' . s:lisp_name, 's'],
  \ ]
let s:patterns.typst = [
  \ ['^\s*#let\s\+\zs[A-Za-z_][A-Za-z0-9_-]*\ze\s*(', 'f'],
  \ ['^\s*#let\s\+\zs[A-Za-z_][A-Za-z0-9_-]*\ze\s*=', 'v'],
  \ ['<\zs[A-Za-z0-9_.:-]\+\ze>', 'l'],
  \ ]
let s:patterns.tex = [
  \ ['\\label{\zs[^}]\+\ze}', 'l'],
  \ ['\\\%(re\)\?newcommand\*\?{\?\\\zs[A-Za-z@]\+', 'm'],
  \ ['\\\%(re\)\?newenvironment\*\?{\zs[^}]\+\ze}', 'm'],
  \ ]
let s:patterns.markdown = [
  \ ['^#\{1,6}\s\+\zs.\{-}\ze\s*#*\s*$', 'h'],
  \ ]
let g:tagsgen_patterns = extend(s:patterns, get(g:, 'tagsgen_patterns', {}))
