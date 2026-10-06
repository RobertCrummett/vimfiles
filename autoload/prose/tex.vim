" prose, for LaTeX: which parts of a document are not prose. The marking of
" buffers is in autoload/prose.vim, which calls prose#tex#run(). See :help
" prose-tex.
"
" LaTeX has no grammar to follow: what an argument is depends on the command
" it belongs to. So the rules are these, with a table of commands below.
"
"   - From \documentclass to \begin{document} everything is code, but for
"     the text of \title, \author, \date and the like.
"   - A command is code: \name, a star after it, and \\. An escaped
"     character (\&, \%, \'e) is text.
"   - Braces are code; what is in them is as what is around them, unless the
"     command they follow says otherwise in the table: \ref{fig:1},
"     \includegraphics[width=3cm]{plot.pdf}, \vspace{1em}.
"   - A [ right after a command starts an optional argument, which is code,
"     but for those the table has as prose: \item[Label], \section[Short].
"   - Math is code, in all its forms: $ $, $$ $$, \( \), \[ \] and the
"     environments. \text{...} in it is prose.
"   - Verbatim text is code: \verb|..| and the verbatim environments.
"   - A comment is neither. It is left as it is.
"
" after/syntax/tex.vim takes its commands from the same table, so that what
" is grey here is not checked for spelling there.

" ------------------------------------------------------------------ table
"
" What follows a command, one letter for each argument in turn:
"   c  {code}             d  {code} that may hold a blank line
"   w  {code} that is drawn as verbatim text
"   u  {code} in which % is no comment
"   v  verbatim: {code}, or code between two of the same character
"   m  {math}             f  for \def: all up to a {code}
"   o  [code], which may be absent
"   p  {prose}            t  [prose], on one line, which may be absent
" and, by themselves:
"   a  any number of [code], each right after the last. This is what a
"      command that is not in the table has.
"   r  any number of [code] and {code}, each right after the last: the keys
"      of a reference or a citation
" A {prose} at the end need not be written: it is what braces are anyway.
" Space may come before an argument, and the end of a line before one that
" is not optional. For a c, a command will do as well: \setlength\parindent.
let s:cmds = {}
let s:envs = {}
function! s:Table(table, spec, names) abort
  for l:name in split(a:names)
    let a:table[l:name] = a:spec
  endfor
endfunction

call s:Table(s:cmds, 'c', 'bibliography bibliographystyle addbibresource input include includeonly subfile'
      \ . ' graphicspath usetikzlibrary usepgfplotslibrary pgfplotsset tikzset geometry hypersetup lstset'
      \ . ' pagestyle thispagestyle pagenumbering vspace hspace addvspace stepcounter refstepcounter value'
      \ . ' arabic roman Roman alph Alph fnsymbol cline fontfamily fontseries fontshape linespread'
      \ . ' enlargethispage phantom hphantom vphantom index hyphenation selectlanguage foreignlanguage'
      \ . ' theoremstyle newlength newsavebox usebox setstretch sisetup ce')
call s:Table(s:cmds, 'cc', 'setlength addtolength setcounter addtocounter fontsize numberwithin counterwithin'
      \ . ' import subimport inputminted settowidth settoheight settodepth multicolumn resizebox'
      \ . ' addcontentsline DeclareMathOperator PassOptionsToPackage')
call s:Table(s:cmds, 'ccc', 'definecolor')
call s:Table(s:cmds, 'oc', 'includegraphics includepdf lstinputlisting usepackage RequirePackage color pagecolor'
      \ . ' textcolor colorbox rowcolor cellcolor columncolor rotatebox bibitem captionsetup si num unit ang'
      \ . ' gls Gls GLS glspl Glspl acrshort acrlong acrfull ac Ac acp acs acl acf')
call s:Table(s:cmds, 'occ', 'SI qty rule numrange newacronym fcolorbox')
call s:Table(s:cmds, 'occc', 'SIrange qtyrange')
call s:Table(s:cmds, 'oooc', 'parbox')
call s:Table(s:cmds, 'co', 'newcounter scalebox')
call s:Table(s:cmds, 'coo', 'raisebox')
call s:Table(s:cmds, 'ococo', 'multirow')
call s:Table(s:cmds, 'copo', 'newtheorem')
call s:Table(s:cmds, 'opc', 'pdfbookmark')
call s:Table(s:cmds, 'cd', 'newglossaryentry')
call s:Table(s:cmds, 'cood', 'newcommand renewcommand providecommand DeclareRobustCommand')
call s:Table(s:cmds, 'coodd', 'newenvironment renewenvironment')
call s:Table(s:cmds, 'ccd', 'NewDocumentCommand RenewDocumentCommand ProvideDocumentCommand DeclareDocumentCommand')
call s:Table(s:cmds, 'ccdd', 'NewDocumentEnvironment RenewDocumentEnvironment')
call s:Table(s:cmds, 'f', 'def edef gdef xdef')
call s:Table(s:cmds, 'u', 'href')
call s:Table(s:cmds, 'v', 'verb path url nolinkurl')
call s:Table(s:cmds, 'w', 'texttt')
call s:Table(s:cmds, 'ov', 'lstinline')
call s:Table(s:cmds, 'ocv', 'mintinline')
call s:Table(s:cmds, 'm', 'ensuremath')
call s:Table(s:cmds, 't', 'item caption part chapter section subsection subsubsection paragraph subparagraph'
      \ . ' marginpar twocolumn subfloat')
" Have "cite" in their names, and their arguments are text.
call s:Table(s:cmds, 'p', 'citetext')
call s:Table(s:cmds, 'cp', 'defcitealias')
" Ends in "ref", and is none: [label]{text}.
call s:Table(s:cmds, 'a', 'hyperref')
" The keys of a label and of a reference. Any other command whose name ends
" in "ref", or has "cite" in it, is taken for one as well: \eqref, \cref,
" \autoref, \figref, \parencite, \textcite, \citeauthor, \nocite.
call s:Table(s:cmds, 'r', 'label ref cite crefrange Crefrange')

" What follows \begin{name}.
call s:Table(s:envs, 'oc', 'subfigure subtable tabular longtable')
call s:Table(s:envs, 'coc', 'tabular*')
call s:Table(s:envs, 'cc', 'tabularx tabulary adjustwidth list')
call s:Table(s:envs, 'oooc', 'minipage')
call s:Table(s:envs, 'ococ', 'wrapfigure wraptable')
call s:Table(s:envs, 'c', 'multicols thebibliography spacing column NiceTabular')
call s:Table(s:envs, 't', 'theorem lemma proposition corollary definition proof remark example claim'
      \ . ' conjecture note exercise solution thm lem prop cor defn rem')

" Environments of math (each also with a star), as the bundled syntax file
" has them; of verbatim text; and of code, in which a comment is a comment.
let s:mathenvs = 'displaymath eqnarray equation math align alignat flalign gather multline xalignat xxalignat'
let s:verbenvs = 'verbatim verbatim* Verbatim Verbatim* lstlisting minted alltt comment filecontents filecontents*'
let s:codeenvs = 'tikzpicture pgfpicture'
" Commands whose argument is text in the midst of math.
let s:textcmds = 'text intertext shortintertext textnormal textrm textit textbf textsf texttt textup textsc'
      \ . ' textsl textmd mbox hbox'
" Commands of the preamble whose argument is text.
let s:titlecmds = 'title subtitle author date institute affil affiliation address keywords abstract dedication'
" In the document they are as \section: \title[Short]{Long}.
call s:Table(s:cmds, 't', s:titlecmds)

function! s:Set(words) abort
  let l:set = {}
  for l:word in split(a:words)
    let l:set[l:word] = 1
  endfor
  return l:set
endfunction
let s:ismath = s:Set(s:mathenvs)
let s:isverb = s:Set(s:verbenvs)
let s:iscode = s:Set(s:codeenvs)
let s:istext = s:Set(s:textcmds)
let s:istitle = s:Set(s:titlecmds)

" For after/syntax/tex.vim.
function! prose#tex#table() abort
  return {'cmds': s:cmds, 'envs': s:envs, 'math': split(s:mathenvs), 'verb': split(s:verbenvs),
        \ 'code': split(s:codeenvs), 'text': split(s:textcmds), 'title': split(s:titlecmds)}
endfunction

" ---------------------------------------------------------------- scanner
"
" A scan goes line by line and can start at any line, given what the line
" starts in. That is s:base, 1 for the document and 2 for the preamble, and
" s:stack, the things that are open, outermost first, each a list
"   [number, class, closer, rest]
" class says what the text in it is:
"   P  prose, in braces: an argument that is prose where its surroundings
"      are not, as \title{..} in the preamble, and any braces in one
"   T  the same for \text{..} in math, which ends with the paragraph
"   C  code that ends with the paragraph, as TeX has it for most arguments
"   D  code that does not: the body of a definition
"   U  code in which % is no comment
"   M  math
"   V  a verbatim environment      K  an environment of code
"   A  nothing yet: arguments that are still to come, on the next line
" closer is what ends it: } ] $ $$ \) \] or e:name for \end{name}. rest is
" what is left of the command's arguments once it has ended.
"
" Braces in the prose of the document itself are not kept track of: what is
" in them is prose as what is around them is, so nothing depends on where
" they end. A brace typed and not yet closed then changes nothing below it.
"
" The flag of a line is s:base plus 1000 times the number of the innermost
" thing open at its start. Numbers are given out when a line starts in
" something that has none yet, and kept in s:blocks:
"   s:blocks[number]  [number of the one it is in, class, closer, rest]
"   s:blocks[key]     the number for these four, so that the same thing in
"                     the same place has the same number in every scan, and
"                     a scan can stop where it finds things as they were.
let s:serial = 0
let s:longest = 10000

" Lines a:from to a:to - 1 (bytes from 0) of the current line are code.
function! s:Mark(from, to) abort
  if a:to > a:from
    if !empty(s:out) && s:out[-1][0] == s:lnum && s:out[-1][3] == a:from + 1
      let s:out[-1][3] = a:to + 1
    else
      call add(s:out, [s:lnum, a:from + 1, s:lnum, a:to + 1])
    endif
  endif
endfunction

" The flag for the start of a line, giving numbers to what has none.
function! s:Flag() abort
  let l:parent = 0
  for l:f in s:stack
    if !l:f[0]
      let l:key = '=' . l:parent . "\n" . l:f[1] . "\n" . l:f[2] . "\n" . l:f[3]
      let l:id = get(s:blocks, l:key, 0)
      if !l:id || !has_key(s:blocks, l:id)
        let s:serial += 1
        let l:id = s:serial
        let s:blocks[l:id] = [l:parent, l:f[1], l:f[2], l:f[3]]
        let s:blocks[l:key] = l:id
      endif
      let l:f[0] = l:id
    endif
    let l:parent = l:f[0]
  endfor
  return 1000 * l:parent + s:base
endfunction

function! s:Restore(flag) abort
  let s:base = a:flag % 1000 == 2 ? 2 : 1
  let s:stack = []
  let l:id = a:flag / 1000
  while l:id && has_key(s:blocks, l:id)
    let l:b = s:blocks[l:id]
    call insert(s:stack, [l:id, l:b[1], l:b[2], l:b[3]])
    let l:id = l:b[0]
  endwhile
endfunction

" The innermost thing has ended: on with the arguments that follow it.
function! s:Pop() abort
  let l:rest = remove(s:stack, -1)[3]
  if !empty(l:rest)
    call s:Args(l:rest)
  endif
endfunction

" The index after the character at a:i.
function! s:After(i) abort
  let l:e = matchend(s:line, '^.', a:i)
  return l:e < 0 ? a:i + 1 : l:e
endfunction

" The ] for the [ at a:i on this line, -1 when it has none.
function! s:Bracket(i) abort
  let l:depth = 0
  let l:i = a:i + 1
  while 1
    let l:i = match(s:line, '[\\{}\]%]', l:i)
    if l:i < 0
      return -1
    endif
    let l:c = s:line[l:i]
    if l:c ==# '\'
      let l:i += 2
      continue
    elseif l:c ==# '%' || (l:c ==# '}' && l:depth == 0)
      return -1
    elseif l:c ==# ']' && l:depth == 0
      return l:i
    endif
    let l:depth += l:c ==# '{' ? 1 : l:c ==# '}' ? -1 : 0
    let l:i += 1
  endwhile
endfunction

" The arguments a:spec of a command, from s:col on. Stops where one of them
" is opened, to be gone on with by s:Pop() when it has ended.
function! s:Args(spec) abort
  let l:spec = a:spec
  while !empty(l:spec)
    let l:k = l:spec[0]
    if l:k ==# 'a' || l:k ==# 'r'
      let l:c = s:line[s:col]
      if l:c ==# '[' || (l:c ==# '{' && l:k ==# 'r')
        call s:Mark(s:col, s:col + 1)
        let s:col += 1
        call add(s:stack, [0, 'C', l:c ==# '[' ? ']' : '}', l:k])
      endif
      return
    endif
    let l:rest = l:spec[1:]
    let l:j = match(s:line, '\S', s:col)
    if l:j < 0
      if l:spec =~# '[cdumvw]'
        call add(s:stack, [0, 'A', '', l:spec])
      endif
      return
    elseif s:line[l:j] ==# '%'
      " Vim's syntax cannot follow arguments past a comment, so nor do we.
      return
    endif
    let l:c = s:line[l:j]
    if l:k ==# 'o'
      " One that nothing has to follow is taken only right after the last.
      if l:c ==# '[' && (l:j == s:col || l:rest =~# '[cdumvwp]')
        call s:Mark(l:j, l:j + 1)
        let s:col = l:j + 1
        call add(s:stack, [0, 'C', ']', l:rest])
        return
      endif
    elseif l:k ==# 't'
      if l:c ==# '['
        let l:e = s:Bracket(l:j)
        if l:e >= 0
          call s:Mark(l:j, l:j + 1)
          let s:brk[l:e] = 1
          let s:col = l:j + 1
        endif
      endif
      return
    elseif l:k ==# 'p'
      if l:c !=# '{' || l:rest !~# '[cdumvwo]'
        return
      endif
      call s:Mark(l:j, l:j + 1)
      let s:col = l:j + 1
      call add(s:stack, [0, 'P', '}', l:rest])
      return
    elseif l:k ==# 'f'
      let l:e = stridx(s:line, '{', l:j)
      call s:Mark(l:j, l:e < 0 ? s:len : l:e + 1)
      let s:col = l:e < 0 ? s:len : l:e + 1
      if l:e >= 0
        call add(s:stack, [0, 'D', '}', ''])
      endif
      return
    elseif l:c ==# '{'
      call s:Mark(l:j, l:j + 1)
      let s:col = l:j + 1
      call add(s:stack, [0, l:k =~# '[cw]' ? 'C' : l:k ==# 'd' ? 'D' : l:k ==# 'm' ? 'M' : 'U', '}', l:rest])
      return
    elseif l:k ==# 'v'
      let l:c = matchstr(s:line, '^.', l:j)
      let l:e = l:c =~# '\a' ? -1 : stridx(s:line, l:c, l:j + len(l:c))
      if l:e < 0
        return
      endif
      call s:Mark(l:j, l:e + len(l:c))
      let s:col = l:e + len(l:c)
    elseif l:c ==# '\' && l:k ==# 'c'
      " A command for an argument: \newcommand\name.
      let l:e = matchend(s:line, '^\\\%(\a\+\|.\)', l:j)
      let l:e = l:e < 0 ? l:j + 1 : l:e
      call s:Mark(l:j, l:e)
      let s:col = l:e
    else
      return
    endif
    let l:spec = l:rest
  endwhile
endfunction

" The command at s:col, in prose.
function! s:Command() abort
  let l:i = s:col
  let l:name = matchstr(s:line, '^\a\+', l:i + 1)
  if empty(l:name)
    let l:c = s:line[l:i + 1]
    if l:c ==# '\'
      " A line break: \\, \\* and \\[2pt].
      let l:e = l:i + (s:line[l:i + 2] ==# '*' ? 3 : 2)
      call s:Mark(l:i, l:e)
      let s:col = l:e
      call s:Args('a')
    elseif l:c ==# '(' || l:c ==# '['
      call s:Mark(l:i, l:i + 2)
      let s:col = l:i + 2
      call add(s:stack, [0, 'M', l:c ==# '(' ? '\)' : '\]', ''])
    elseif l:c ==# ')' || l:c ==# ']'
      call s:Mark(l:i, l:i + 2)
      let s:col = l:i + 2
    else
      " An escaped character is text.
      let s:col = s:After(l:i + 1)
    endif
    return
  endif
  let l:e = l:i + 1 + len(l:name)
  if s:line[l:e] ==# '*'
    let l:e += 1
  endif
  if l:name ==# 'begin' || l:name ==# 'end'
    let l:m = matchlist(s:line, '^\s*{\s*\([^{}%\\[:space:]]*\)\s*}', l:e)
    if empty(l:m)
      call s:Mark(l:i, l:e)
      let s:col = l:e
      return
    endif
    let l:e += len(l:m[0])
    call s:Mark(l:i, l:e)
    let s:col = l:e
    if l:name ==# 'end'
      return
    endif
    let l:env = l:m[1]
    let l:plain = substitute(l:env, '\*$', '', '')
    if has_key(s:ismath, l:plain)
      call add(s:stack, [0, 'M', 'e:' . l:env, ''])
    elseif has_key(s:isverb, l:env)
      call add(s:stack, [0, 'V', 'e:' . l:env, ''])
    elseif has_key(s:iscode, l:env)
      call add(s:stack, [0, 'K', 'e:' . l:env, ''])
    else
      call s:Args(get(s:envs, l:env, get(s:envs, l:plain, 'a')))
    endif
    return
  endif
  call s:Mark(l:i, l:e)
  let s:col = l:e
  let l:spec = get(s:cmds, l:name, '')
  if empty(l:spec)
    if l:name =~# 'ref$\|[cC]ite'
      let l:spec = 'r'
    elseif l:name ==# 'documentclass' || l:name ==# 'documentstyle'
      " At the start of a line: not the one a manual writes about.
      if empty(s:stack) && l:i == match(s:line, '\S')
        let s:base = 2
      endif
      return
    else
      let l:spec = 'a'
    endif
  endif
  if l:spec ==# 'r'
    " Space may come before the first of the keys.
    let l:j = match(s:line, '\S', l:e)
    if l:j < 0 || s:line[l:j] !~# '[\[{]'
      return
    endif
    let s:col = l:j
  endif
  call s:Args(l:spec)
endfunction

" Prose: the document itself, or braces of prose.
function! s:Prose() abort
  let l:group = !empty(s:stack)
  while 1
    let l:i = match(s:line, '[\\{}$%&#\]]', s:col)
    if l:i < 0
      let s:col = s:len
      return
    endif
    let l:c = s:line[l:i]
    let s:col = l:i + 1
    if l:c ==# '\'
      let s:col = l:i
      call s:Command()
      return
    elseif l:c ==# '%'
      let s:col = s:len
      return
    elseif l:c ==# '$'
      let l:e = l:i + (s:line[l:i + 1] ==# '$' ? 2 : 1)
      call s:Mark(l:i, l:e)
      let s:col = l:e
      call add(s:stack, [0, 'M', l:e - l:i == 2 ? '$$' : '$', ''])
      return
    elseif l:c ==# ']'
      " The end of an optional argument of prose.
      if has_key(s:brk, l:i)
        call s:Mark(l:i, l:i + 1)
      endif
    elseif l:c ==# '#'
      let s:col = matchend(s:line, '^#\+\d\=', l:i)
      call s:Mark(l:i, s:col)
    else
      call s:Mark(l:i, l:i + 1)
      if l:group && l:c ==# '{'
        call add(s:stack, [0, 'P', '}', ''])
      elseif l:group && l:c ==# '}'
        call s:Pop()
        return
      endif
    endif
  endwhile
endfunction

" The preamble: all of it code, but for the text of a title.
function! s:Preamble() abort
  let l:from = s:col
  while 1
    let l:i = match(s:line, '[\\%]', s:col)
    if l:i < 0 || s:line[l:i] ==# '%'
      call s:Mark(l:from, l:i < 0 ? s:len : l:i)
      let s:col = s:len
      return
    endif
    let l:name = matchstr(s:line, '^\a\+', l:i + 1)
    if empty(l:name)
      let s:col = s:After(l:i + 1)
      continue
    endif
    let s:col = l:i + 1 + len(l:name)
    if l:name ==# 'begin'
      let l:e = matchend(s:line, '^\s*{\s*document\s*}', s:col)
      if l:e >= 0
        call s:Mark(l:from, l:e)
        let s:col = l:e
        let s:base = 1
        return
      endif
    elseif has_key(s:istitle, l:name)
      " \title[Short]{Long}: both are text.
      let l:m = matchlist(s:line, '^\(\s*\[\)\([^\]]*\)\]\s*{', s:col)
      if !empty(l:m)
        call s:Mark(l:from, s:col + len(l:m[1]))
        let l:from = s:col + len(l:m[1]) + len(l:m[2])
        let s:col += len(l:m[0]) - 1
      endif
      let l:e = matchend(s:line, '^\s*{', s:col)
      if l:e >= 0
        call s:Mark(l:from, l:e)
        let s:col = l:e
        call add(s:stack, [0, 'P', '}', ''])
        return
      endif
    endif
  endwhile
endfunction

" Code in braces or brackets: to the one that closes it.
function! s:Code() abort
  let l:top = s:stack[-1]
  let l:from = s:col
  let l:pat = l:top[2] ==# ']' ? '[\\{\]%]' : '[\\{}%]'
  while 1
    let l:i = match(s:line, l:pat, s:col)
    if l:i < 0
      call s:Mark(l:from, s:len)
      let s:col = s:len
      return
    endif
    let l:c = s:line[l:i]
    if l:c ==# '\'
      let s:col = s:After(l:i + 1)
    elseif l:c ==# '%'
      if l:top[1] ==# 'U'
        let s:col = l:i + 1
        continue
      endif
      call s:Mark(l:from, l:i)
      let s:col = s:len
      return
    elseif l:c ==# '{'
      call s:Mark(l:from, l:i + 1)
      let s:col = l:i + 1
      call add(s:stack, [0, l:top[1], '}', ''])
      return
    else
      call s:Mark(l:from, l:i + 1)
      let s:col = l:i + 1
      call s:Pop()
      return
    endif
  endwhile
endfunction

" Math: to what closes it, with the text in it left out.
function! s:Math() abort
  let l:close = s:stack[-1][2]
  let l:from = s:col
  let l:pat = l:close ==# '}' ? '[\\$%{}]' : '[\\$%]'
  while 1
    let l:i = match(s:line, l:pat, s:col)
    if l:i < 0 || s:line[l:i] ==# '%'
      call s:Mark(l:from, l:i < 0 ? s:len : l:i)
      let s:col = s:len
      return
    endif
    let l:c = s:line[l:i]
    let l:e = -1
    if l:c ==# '$'
      let s:col = l:i + (s:line[l:i + 1] ==# '$' && l:close !=# '$' ? 2 : 1)
      if l:close ==# '$' || (l:close ==# '$$' && s:col == l:i + 2)
        let l:e = s:col
      endif
    elseif l:c ==# '{'
      call s:Mark(l:from, l:i + 1)
      let s:col = l:i + 1
      call add(s:stack, [0, 'M', '}', ''])
      return
    elseif l:c ==# '}'
      let l:e = l:i + 1
    else
      let l:name = matchstr(s:line, '^\a\+', l:i + 1)
      let s:col = l:i + 1 + len(l:name)
      if empty(l:name)
        let s:col = s:After(l:i + 1)
        if l:close ==# '\' . s:line[l:i + 1]
          let l:e = l:i + 2
        endif
      elseif l:name ==# 'end'
        if l:close[0 : 1] ==# 'e:'
          let l:e = matchend(s:line, '\V\^\s\*{\s\*' . escape(l:close[2:], '\') . '\s\*}', s:col)
        endif
      elseif has_key(s:istext, l:name)
        let l:j = matchend(s:line, '^\s*{', s:col)
        if l:j >= 0
          call s:Mark(l:from, l:j)
          let s:col = l:j
          call add(s:stack, [0, 'T', '}', ''])
          return
        endif
      endif
    endif
    if l:e >= 0
      call s:Mark(l:from, l:e)
      let s:col = l:e
      call s:Pop()
      return
    endif
  endwhile
endfunction

" A verbatim environment, or one of code: to its \end.
function! s:Verbatim() abort
  let l:top = s:stack[-1]
  let l:from = s:col
  let l:end = '\end{' . l:top[2][2:] . '}'
  let l:i = stridx(s:line, l:end, s:col)
  if l:top[1] ==# 'K'
    let l:p = match(s:line, '\%(^\|[^\\]\)\%(\\\\\)*\zs%', s:col)
    if l:p >= 0 && (l:i < 0 || l:p < l:i)
      call s:Mark(l:from, l:p)
      let s:col = s:len
      return
    endif
  endif
  if l:i < 0
    call s:Mark(l:from, s:len)
    let s:col = s:len
    return
  endif
  let s:col = l:i + len(l:end)
  call s:Mark(l:from, s:col)
  call s:Pop()
endfunction

function! s:Line(line) abort
  let s:line = a:line
  let s:len = len(a:line)
  let s:col = 0
  let s:brk = {}
  if s:len > s:longest
    " A line cannot be scanned in parts, and every step in it costs Vim a
    " copy of it: 30 ms at 5000 bytes, two seconds at 100000. Such a line is
    " data, not writing. It is left as the syntax file has it, and what
    " was open before it is still open after it.
    return
  endif
  if !empty(s:stack)
    if a:line =~# '^\s*$'
      " The paragraph ends, and with it what TeX does not let run past it:
      " math in a line of text, and an argument that is not a definition.
      let l:i = 0
      for l:f in s:stack
        if l:f[1] =~# '[CUAT]' || (l:f[1] ==# 'M' && (l:f[2] ==# '$' || l:f[2] ==# '\)'))
          call remove(s:stack, l:i, -1)
          break
        endif
        let l:i += 1
      endfor
      return
    elseif s:stack[-1][1] ==# 'A'
      call s:Args(remove(s:stack, -1)[3])
    endif
  endif
  while s:col < s:len
    if empty(s:stack)
      if s:base == 1
        call s:Prose()
      else
        call s:Preamble()
      endif
    else
      let l:class = s:stack[-1][1]
      if l:class ==# 'P' || l:class ==# 'T'
        call s:Prose()
      elseif l:class ==# 'M'
        call s:Math()
      elseif l:class ==# 'V' || l:class ==# 'K'
        call s:Verbatim()
      elseif l:class ==# 'A'
        let s:col = s:len
      else
        call s:Code()
      endif
    endif
  endwhile
endfunction

" Scans a:lines from the start of line a:start (from 0), which starts with
" a:flag. What it takes and returns is told in autoload/prose.vim. Every
" line is one a scan can start at, so there is nothing a:cap could cut
" short, and no frame to go back out of.
function! s:Scan(lines, start, flag, safe, hi, blocks, budget, span) abort
  let s:blocks = a:blocks
  let s:out = []
  let l:n = len(a:lines)
  let l:known = len(a:safe)
  let l:arrive = []
  let [l:end, l:endflag, l:more] = [l:n, 0, 0]
  let l:began = reltime()
  call s:Restore(a:flag)
  let l:ln = a:start
  try
    while l:ln < l:n
      let l:flag = s:Flag()
      if l:ln > a:start
        if l:ln > a:hi && l:ln < l:known && a:safe[l:ln] == l:flag
          let l:end = l:ln
          break
        elseif a:budget > 0 && (l:ln - a:start >= a:span || (l:ln % 16 == 0 && reltimefloat(reltime(l:began)) > a:budget))
          let [l:end, l:endflag, l:more] = [l:ln, l:flag, 1]
          break
        endif
      endif
      call add(l:arrive, [l:ln, l:flag])
      let s:lnum = l:ln + 1
      call s:Line(a:lines[l:ln])
      let l:ln += 1
    endwhile
    return {'items': s:out, 'end': l:end, 'endflag': l:endflag, 'arrive': l:arrive,
          \ 'more': l:more, 'stuck': 0, 'outer': -1}
  finally
    let [s:blocks, s:stack, s:line] = [{}, [], '']
  endtry
endfunction

" For autoload/prose.vim: a go at a buffer's lines.
function! prose#tex#run(lines, start, flag, safe, hi, blocks, budget, cap, span) abort
  return s:Scan(a:lines, a:start, a:flag, a:safe, a:hi, a:blocks, a:budget, a:span)
endfunction

" The code in a LaTeX document given as a list of lines.
function! prose#tex#scan(lines) abort
  return s:Scan(a:lines, 0, 1, [], len(a:lines), {}, 0, 0).items
endfunction
