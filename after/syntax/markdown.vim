" Math. The runtime syntax knows nothing of $...$, so the _ in $F_a$ was
" read as an italic marker between word characters and marked
" markdownError. Give math its own regions: inside them nothing else is
" matched, so the underscore is just an underscore, and the text is not
" spell checked either.
"
" Inline math stays on one line and follows the usual rule that the opening
" $ is not followed by a space and the closing $ is neither preceded by one
" nor followed by a digit, so "costs $5 and $6" is prose, not a formula.
" Display math $$...$$ may span lines. Coloured by colors/custom.vim like
" Typst's math.
syn region markdownMath matchgroup=markdownMathDelim
  \ start="\\\@<!\$\S\@=" end="\S\@<=\$\d\@!" skip="\\\$"
  \ oneline keepend contains=@NoSpell
syn region markdownMathBlock matchgroup=markdownMathDelim
  \ start="\\\@<!\$\$" end="\$\$"
  \ keepend contains=@NoSpell
syn cluster markdownInline add=markdownMath,markdownMathBlock

hi def link markdownMath      Special
hi def link markdownMathBlock Special
hi def link markdownMathDelim Special
