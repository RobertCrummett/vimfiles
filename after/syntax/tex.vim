" Layered on $VIMRUNTIME/syntax/tex.vim, to give LaTeX the same few colours
" as Typst (colors/custom.vim): commands, references, math, raw text. And to
" have spelling checked in the prose and nowhere else: where the prose
" plugin draws grey while 'spell' is on (:help prose-tex), nothing is to be
" marked as misspelled. The commands that take something other than prose
" for an argument are therefore taken from its table, and a region here ends
" where the plugin's scanner has it end.
"
" Of two rules that match at the same place Vim takes the one defined last.
" Much below depends on that: a rule here wins from the bundled one, and
" within this file the order of the sections matters.
let s:table = prose#tex#table()

" The bundled rules check the text of a section and of braces, and leave
" the text before the first \section of a chapter in a file of its own.
syntax spell toplevel
" They also leave all that is in brackets, [like this], for the options
" that brackets often hold. Those have rules of their own below; any other
" brackets hold prose.
syntax region texMatcher
    \ transparent
    \ matchgroup=texDelimiter start="\[" end="]"
    \ contains=@texMatchGroup,texError
" An accent is part of a word: caf\'e. As a rule of its own it is drawn as a
" command, and keeps the rest of the word from being checked.
silent! syntax clear texAccent


" ------------------------------------------------------------------- math
"
" Math is one colour, whatever is in it. The bundled @texMathZoneGroup
" colours a formula piece by piece: \omega and \frac as commands, _x and ^2
" as commands too, = as an operator, braces as delimiters and the rest as
" math. Here a math zone holds only what must keep its own colour or keep
" the zone from ending in the wrong place:
"   texComment      a comment is a comment (and may hold a $)
"   texRefZone      \label{eqn:1} is a label wherever it stands
"   texMathText     \text{...} is prose, with all that prose may hold
"   texMathEscape   \% is not a comment, \$ not the end
syntax cluster texMathZoneGroup
    \ contains=texComment
            \ ,texRefZone
            \ ,texMathText
            \ ,texMathEscape
            \ ,@NoSpell

syntax match texMathEscape
    \ contained
    \ /\\\A/
" Only for \ensuremath{a_{b}}, which ends at its own brace.
syntax region texMathBraces
    \ contained transparent
    \ start=/{/ end=/}/
    \ contains=@texMathZoneGroup,texMathBraces

" The bundled rule draws \text{ as a command, and leaves the text plain.
" (The delimiters need a group that is not the region's own. With its own,
" the } is part of the region, where the bundled rule for a stray } takes
" it, and the region does not end.)
syntax clear texMathText
execute 'syntax region texMathText contained matchgroup=texMathTextDelim'
    \ 'start=/\\\%(' . join(s:table.text, '\|') . '\)\s*{/ end=/}/ end=/^\s*$/'
    \ 'contains=@texMatchGroup'

" The delimiters of inline and display math, which the bundled rules draw as
" texDelimiter like any brace, and \ensuremath{ as a command. The same
" regions, with the delimiters in a group of the zone's colour, and without
" "keepend": with it a zone ends at a \] in a comment. Math in a line of
" text ends with the paragraph, as it does for TeX: a $ that is typed does
" not turn the rest of the file into math until it is closed.
syntax clear texMathZoneV texMathZoneW texMathZoneX texMathZoneY texMathZoneZ
syntax region texMathZoneV
    \ matchgroup=texMathZoneDelim start="\\(" end="\\)\|%stopzone\>" end="^\s*$"
    \ contains=@texMathZoneGroup
syntax region texMathZoneW
    \ matchgroup=texMathZoneDelim start="\\\[" end="\\]\|%stopzone\>"
    \ contains=@texMathZoneGroup
syntax region texMathZoneX
    \ matchgroup=texMathZoneDelim start="\$" skip="\%(\\\\\)*\\\$" end="\$" end="%stopzone\>" end="^\s*$"
    \ contains=@texMathZoneGroup
syntax region texMathZoneY
    \ matchgroup=texMathZoneDelim start="\$\$" end="\$\$" end="%stopzone\>"
    \ contains=@texMathZoneGroup
syntax region texMathZoneZ
    \ matchgroup=texMathZoneDelim start="\\ensuremath\s*{" end="}" end="%stopzone\>"
    \ contains=@texMathZoneGroup,texMathBraces
" The environments, in place of the bundled texMathZoneA and so on, for the
" same reason. Their \begin{...} and \end{...} are part of the zone and so
" have its colour.
execute 'syntax region texMathZoneEnv'
    \ 'start="\\begin\s*{\s*\z(\%(' . join(s:table.math, '\|') . '\)\*\=\)\s*}"'
    \ 'end="\\end\s*{\s*\z1\s*}" end="%stopzone\>"'
    \ 'contains=@texMathZoneGroup'
syntax cluster texMathZones add=texMathZoneEnv

highlight default link texMathZoneDelim texMath
highlight default link texMathZoneEnv   texMath
highlight default link texMathEscape    texMath
highlight default link texMathText      texMath
highlight default link texMathTextDelim texMath


" ------------------------------------------------------------- references
"
" References, labels and citations. The bundled rules know \label, \ref,
" \eqref, \pageref, \vref and \cite, \citet, \citep, draw the command and
" its braces as a command, and only the key as a reference. Here the whole
" of \ref{fig:1} is one reference, as @fig:1 is in Typst, and so is any
" command whose name ends in "ref" or has "cite" in it: \cref and \autoref,
" a \figref of one's own, natbib's \citeauthor, biblatex's \parencite and
" \textcite. Optional arguments, [see][p.~5], belong to it. Nothing in it is
" checked for spelling.
syntax clear texRefZone texRefOption texCite
let s:other = filter(keys(s:table.cmds), {_, name -> name =~# 'ref$\|[cC]ite' && s:table.cmds[name] !=# 'r'})
let s:named = filter(keys(s:table.cmds), {_, name -> s:table.cmds[name] ==# 'r'})
execute 'syntax match texRefZone'
    \ '/\\\%(' . join(s:named, '\|') . '\|\%(\%(' . join(s:other, '\|') . '\)\a\@!\)\@!\%(\a*ref\|\a*[cC]ite\a*\)\)\*\=\a\@!\ze\s*[\[{]/'
    \ 'nextgroup=texRefOption,texCite skipwhite'
" (The delimiters are in a group of their own, or the braces in a key would
" start at the { of the key itself.)
syntax region texRefOption
    \ contained
    \ matchgroup=texRefDelim start=/\[/ end=/\]/ end=/^\s*$/
    \ contains=texComment,texArgEscape,@NoSpell
    \ nextgroup=texRefOption,texCite
syntax region texCite
    \ contained
    \ matchgroup=texRefDelim start=/{/ end=/}/ end=/^\s*$/
    \ contains=texComment,texArgEscape,texCiteBraces,@NoSpell
    \ nextgroup=texRefOption,texCite
syntax region texCiteBraces
    \ contained transparent
    \ start=/{/ end=/}/ end=/^\s*$/
    \ contains=texComment,texArgEscape,texCiteBraces,@NoSpell

highlight default link texRefOption texRefZone
highlight default link texRefDelim  texRefZone


" --------------------------------------------------------------- headings
"
" Section titles, as headings are in Typst: the argument of \section and
" its kin is drawn in a group of its own. It starts at a { that follows the
" command, with a star and a [short title] in between at most.
syntax region texSectionTitle
    \ contained
    \ containedin=texPartZone,texChapterZone,texSectionZone,texSubSectionZone,texSubSubSectionZone,texParaZone,texSubParaZone
    \ matchgroup=texDelimiter
    \ start=/{\%(\\\%(part\|chapter\|\%(sub\)*section\|\%(sub\)\=paragraph\)\*\=\s*\%(\[[^\]]*\]\s*\)\={\)\@80<=/
    \ end=/}/
    \ contains=@texMatchGroup

highlight default texSectionTitle term=bold,underline cterm=bold,underline gui=bold,underline

" The document's title is a heading too. The bundled rule has \title{ and
" \author{ with their braces as one command, and the text of both in one
" group; here the command stands alone, the braces are braces, and only the
" title is drawn as a heading. What they hold is prose, but without the
" bundled pairing of [ ] and ( ): in "the interval [0,1)" that runs on past
" the closing brace, and in a preamble takes the rest of it for the title.
syntax clear texTitle
" (A command of the preamble, see below, which \title is to win from there.)
syntax match texPreambleCmd
    \ contained
    \ /\\[a-zA-Z@]\+/
syntax cluster texTitleGroup
    \ contains=texComment,texTitleBraces,texStatement,texRefZone,texArgCmd,texArgOpt
            \ ,texSpecialChar,texLigature,texDelimiter,@texMathZones,@Spell
syntax region texTitleBraces
    \ contained transparent
    \ matchgroup=texDelimiter start=/{/ end=/}/
    \ contains=@texTitleGroup
execute 'syntax match texTitleCmd'
    \ '/\\\%(' . join(s:table.title, '\|') . '\)\a\@!\ze\s*\%(\[[^\]]*\]\s*\)\={/'
    \ 'nextgroup=texTitleOpt,texTitle,texAuthor skipwhite'
syntax region texTitleOpt
    \ contained oneline
    \ matchgroup=texDelimiter start=/\[/ end=/\]/
    \ contains=@texTitleGroup
    \ nextgroup=texTitle,texAuthor skipwhite
" texTitle is the later of the two, so it is the one taken where both fit.
syntax region texAuthor
    \ contained
    \ matchgroup=texDelimiter start=/{/ end=/}/
    \ contains=@texTitleGroup
syntax region texTitle
    \ contained
    \ matchgroup=texDelimiter start=/{\%(\\title\>[^{]*{\)\@60<=/ end=/}/
    \ contains=@texTitleGroup

highlight default link texTitleCmd texSection
highlight default link texTitle    texSectionTitle


" --------------------------------------------------------------- preamble
"
" From \documentclass to \begin{document} there is no prose but the text of
" a title: commands are commands, and the rest is neither coloured nor
" checked for spelling. (The bundled rules check all that is in braces
" there, and "a4paper" is a spelling mistake.)
syntax region texPreambleZone
    \ start=/^\s*\\document\%(class\|style\)\>/ end=/\ze\\begin\s*{\s*document\s*}/
    \ contains=texComment,texArgEscape,texPreambleCmd,texTitleCmd

highlight default link texPreambleCmd texStatement


" -------------------------------------------------------------- arguments
"
" What there is in an argument that is code: braces, comments, commands,
" and escaped characters, so that \% starts no comment and \} ends nothing.
" As for TeX and for the plugin, such an argument ends with the paragraph,
" unless it is the body of a definition.
syntax cluster texArgGroup contains=texArgBraces,texComment,texArgStatement,texArgEscape,@NoSpell
syntax cluster texArgLongGroup contains=texArgLongBraces,texComment,texArgStatement,texArgEscape,@NoSpell
syntax region texArgBraces
    \ contained transparent
    \ matchgroup=texDelimiter start=/{/ end=/}/ end=/^\s*$/
    \ contains=@texArgGroup
syntax region texArgLongBraces
    \ contained transparent
    \ matchgroup=texDelimiter start=/{/ end=/}/
    \ contains=@texArgLongGroup
syntax match texArgStatement
    \ contained
    \ /\\\a\+/
syntax match texArgEscape
    \ contained
    \ /\\\A/
" And in one that is taken as it is, a URL or verbatim text: only braces.
syntax region texArgRaw
    \ contained transparent
    \ start=/{/ end=/}/ end=/^\s*$/
    \ contains=texArgRaw,texArgEscape

highlight default link texArgStatement texStatement

" The arguments of a command, as one letter each tells in the table of
" autoload/prose/tex.vim: a region for the first of them, which is followed
" by the regions for the rest. Returns the names of the groups that an
" argument list may start with.
let s:made = {}
function! s:Flags(spec) abort
  return (a:spec =~# '[cdumvwptf]' ? ' skipwhite' : '') . (a:spec =~# '[cdumvw]' ? ' skipnl' : '')
endfunction
function! s:Chain(spec) abort
  " Prose at the end is what braces are anyway.
  let l:spec = substitute(a:spec, 'p\+$', '', '')
  if empty(l:spec) || l:spec =~# '[arm]'
    return []
  endif
  let l:k = l:spec[0]
  let l:after = l:k ==# 'f' ? s:Chain('d') : s:Chain(l:spec[1:])
  let l:name = 'texArg_' . l:spec
  let l:names = [l:name]
  if l:k =~# '[cv]'
    call add(l:names, l:name . '_')
  endif
  if !has_key(s:made, l:name)
    let s:made[l:name] = 1
    let l:next = empty(l:after) ? '' : ' nextgroup=' . join(l:after, ',') . (l:k ==# 'f' ? '' : s:Flags(l:spec[1:]))
    let l:region = 'syntax region ' . l:name . ' contained matchgroup=texDelimiter '
    if l:k ==# 'o'
      execute l:region . 'start=/\[/ end=/\]/ end=/^\s*$/ contains=@texArgGroup' . l:next
    elseif l:k ==# 't'
      execute l:region . 'oneline start=/\[/ end=/\]/ contains=@texMatchGroup' . l:next
    elseif l:k ==# 'p'
      execute l:region . 'start=/{/ end=/}/ contains=@texMatchGroup' . l:next
    elseif l:k ==# 'c'
      execute l:region . 'start=/{/ end=/}/ end=/^\s*$/ contains=@texArgGroup' . l:next
      " A command will do for it: \setlength\parindent{0pt}.
      execute 'syntax match' l:name . '_ contained /\\\%(\a\+\|.\)/' . l:next
      execute 'highlight default link' l:name . '_ texStatement'
    elseif l:k ==# 'w'
      execute l:region . 'start=/{/ end=/}/ end=/^\s*$/ contains=@texArgGroup' . l:next
      execute 'highlight default link' l:name 'texZone'
    elseif l:k ==# 'd'
      execute l:region . 'start=/{/ end=/}/ contains=@texArgLongGroup' . l:next
    elseif l:k ==# 'f'
      " \def\name#1#2 up to the body.
      execute 'syntax match' l:name 'contained /[^{]\+/ contains=texArgStatement,texArgEscape' . l:next
    else
      execute l:region . 'start=/{/ end=/}/ end=/^\s*$/ contains=texArgRaw,texArgEscape' . l:next
      execute 'highlight default link' l:name 'texZone'
      if l:k ==# 'v'
        " \verb|...|: between two of the same character, on one line.
        execute 'syntax region' l:name . '_ contained oneline start=/\z([^[:space:]a-zA-Z{]\)/ end=/\z1/' . l:next
        execute 'highlight default link' l:name . '_ texZone'
      endif
    endif
  endif
  return l:names + (l:k =~# '[otf]' ? l:after : [])
endfunction

" The commands of the table, but for the references above and the commands
" whose first argument is prose (\section, \item, \caption), which need
" nothing. These take the place of the bundled rules for \newcommand, \def,
" \verb, \input and \includegraphics.
let s:by = {}
for [s:name, s:spec] in items(s:table.cmds)
  if s:spec[0] !=# 't'
    let s:by[s:spec] = add(get(s:by, s:spec, []), s:name)
  endif
endfor
for [s:spec, s:names] in items(s:by)
  let s:next = s:Chain(s:spec)
  if !empty(s:next)
    execute 'syntax match texArgCmd /\\\%(' . join(s:names, '\|') . '\)\*\=\a\@!/'
        \ 'nextgroup=' . join(s:next, ',') . s:Flags(s:spec)
  endif
endfor

highlight default link texArgCmd texStatement

" A [ right after a command that is not in the table, or after \\, starts
" an optional argument, and so does one right after that: \todo[inline],
" \makebox[2cm][c], \\[2pt]. (The command is one whose backslash is not the
" second of a \\: an even number of them may come before it.)
execute 'syntax region texArgOpt matchgroup=texDelimiter'
    \ 'start=/\[\%(\\\@<!\%(\\\\\)*\\\%(\\\|\%(\%(' . join(filter(keys(s:table.cmds), {_, name -> s:table.cmds[name] !=# 'a'}), '\|') . '\)\a\@!\)\@!\a\+\)\*\=\[\)\@40<=/'
    \ 'end=/\]/ end=/^\s*$/ contains=@texArgGroup nextgroup=texArgOptMore'
syntax region texArgOptMore
    \ contained
    \ matchgroup=texDelimiter start=/\[/ end=/\]/ end=/^\s*$/
    \ contains=@texArgGroup
    \ nextgroup=texArgOptMore


" ----------------------------------------------------------- environments
"
" \begin{figure} is one command, as the bundled rules already have
" \begin{document}: the braces around the name of an environment take the
" colour of the name instead of that of a delimiter. Any number of [options]
" may follow a \begin{...}, and none an \end{...}. The name is on one line:
" a \begin{equatio that is being typed takes nothing below it along.
syntax clear texBeginEndName
syntax region texBeginEndName
    \ contained oneline
    \ matchgroup=texBeginEndName start="{" end="}"
    \ contains=texComment
    \ nextgroup=texBeginOpt
syntax region texBeginOpt
    \ contained
    \ matchgroup=texDelimiter start=/\[\%(\\begin\s*{[^{}]*}\[\)\@80<=/ end=/\]/ end=/^\s*$/
    \ contains=@texArgGroup
    \ nextgroup=texArgOptMore
" It follows \begin and \end as their nextgroup. The bundled cluster for the
" body of a \newcommand lists it as well, where it would make an environment
" name of any {braces}; that went unnoticed only because a later rule won.
syntax cluster texCmdGroup remove=texBeginEndName

" The environments of the table, which take more than that: the columns of
" \begin{tabular}{lcc}, the width of \begin{subfigure}[b]{0.3\textwidth},
" the name of \begin{theorem}[Pythagoras]. A name without a star stands for
" the one with a star too, so those with one are defined after it.
let s:by = {}
for [s:name, s:spec] in items(s:table.envs)
  let s:by[s:spec] = add(get(s:by, s:spec, []), s:name)
endfor
for s:starred in [0, 1]
  for [s:spec, s:names] in items(s:by)
    let s:names = filter(copy(s:names), {_, name -> (name =~# '\*$') == s:starred})
    let s:next = s:Chain(s:spec)
    if !empty(s:names) && !empty(s:next)
      execute 'syntax match texBeginEndArgs'
          \ '/\\begin\s*{\s*\%(' . join(map(s:names, {_, name -> escape(name, '*')}), '\|') . '\)' . (s:starred ? '' : '\*\=') . '\s*}/'
          \ 'nextgroup=' . join(s:next, ',') . s:Flags(s:spec)
    endif
  endfor
endfor

highlight default link texBeginEndArgs texBeginEndName

" Verbatim text, beside the bundled verbatim, and environments of code, in
" which a comment is a comment and nothing is prose.
for s:name in s:table.verb
  execute 'syntax region texZone start="\\begin{' . escape(s:name, '*') . '}" end="\\end{' . escape(s:name, '*') . '}\|%stopzone\>"'
endfor
execute 'syntax region texCodeZone matchgroup=texBeginEndName'
    \ 'start="\\begin{\z(' . join(s:table.code, '\|') . '\)}" end="\\end{\z1}"'
    \ 'contains=texComment,texArgStatement,texArgEscape,@NoSpell'


" Where a command may stand, these may: in the document, in braces, in bold
" and italic text. (texRefZone and texZone are there under their own names.)
for s:cluster in ['texFoldGroup', 'texMatchGroup', 'texMatchNMGroup', 'texBoldGroup', 'texItalGroup', 'texStyleGroup']
  execute 'syntax cluster' s:cluster 'add=texArgCmd,texArgOpt,texBeginEnd,texBeginEndArgs,texCodeZone,texTitleCmd'
endfor


" ---------------------------------------------------------------- syncing
"
" The bundled rules have Vim look for the syntax of a line by going back 50
" to 200 lines from it. That starts in the middle of a preamble, a listing
" or a long equation as if it were text: wrong colours, and spelling marks
" in code, whenever a file is opened where it was left. From the start of
" the file it is always right, and costs the parsing of what is above the
" window, once: 0.13 ms a line, so half a second at 4000 lines. Beyond that
" the bundled way stays, and the prose plugin is told to hold its marks
" back (s:Wait() in autoload/prose.vim), which that way of syncing needs.
if line('$') <= 4000
  syntax sync fromstart
  unlet! b:prose_hold
else
  let b:prose_hold = 1
endif

delfunction s:Chain
delfunction s:Flags
unlet s:table s:made s:by s:other s:named s:name s:spec s:names s:next s:starred s:cluster
