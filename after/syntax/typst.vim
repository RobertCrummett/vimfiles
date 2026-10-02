" The bundled syntax draws the $ that delimits math with hard-coded standard
" groups (Special, Number, Noise), so no colorscheme link can reach them.
" Redefine the three math regions identically, but with their delimiters in
" a typst-specific group that colors/custom.vim links like the math itself.
syntax clear typstMarkupDollar typstCodeDollar typstHashtagDollar

syntax region typstMarkupDollar
    \ matchgroup=typstMathDelim start=/\\\@<!\$/ end=/\\\@<!\$/
    \ contains=@typstMath
syntax region typstCodeDollar
    \ contained
    \ matchgroup=typstMathDelim start=/\\\@<!\$/ end=/\\\@<!\$/
    \ contains=@typstMath
syntax region typstHashtagDollar
    \ matchgroup=typstMathDelim start=/#\$/ end=/\\\@<!\$/
    \ contains=@typstMath

highlight default link typstMathDelim Special


" Math is one colour, whatever is in it. The bundled @typstMath cluster
" brings in @typstHashtag, so the #(AA, BB) in
"   $ bal(#(AA, BB), #(CC, DD, EE)) = ... $
" is coloured as code is elsewhere, and the string in $J_("scatt " sigma)$ has
" no colour at all. Here the cluster is the bundled one without the code
" rules, and a # expression gets rules that only keep track of where it
" ends: its delimiters nest, and a string or math inside it may hold a ) or
" a $ that must not end anything. All of it is typstMathCode, which
" colors/custom.vim links like the math around it.
syntax cluster typstMath
    \ contains=@typstCommon
            \ ,typstMathCode
            \ ,typstMathHashParen
            \ ,typstMathHashBrace
            \ ,typstMathHashBracket
            \ ,typstMathIdentifier
            \ ,typstMathFunction
            \ ,typstMathNumber
            \ ,typstMathSymbol
            \ ,typstMathBold
            \ ,typstMathScripts
            \ ,typstMathQuote

" #name, #name.field, and the arguments that follow at once.
syntax match typstMathCode
    \ contained
    \ /#\K\k*\%(\.\K\k*\)*/
    \ nextgroup=typstMathCodeParen,typstMathCodeBracket
" #( ), #{ } and #[ ] open only after a #; the plain ones only inside those
" or as arguments, or every parenthesis of the math itself would be one.
" matchgroup: without it the ( of #( is open to the contained items, and
" starts a second region inside the first, which then never ends.
syntax region typstMathHashParen
    \ contained
    \ matchgroup=typstMathCode start=/#(/ end=/)/
    \ contains=@typstMathCodeIn
    \ nextgroup=typstMathCodeParen,typstMathCodeBracket
syntax region typstMathHashBrace
    \ contained
    \ matchgroup=typstMathCode start=/#{/ end=/}/
    \ contains=@typstMathCodeIn
syntax region typstMathHashBracket
    \ contained
    \ matchgroup=typstMathCode start=/#\[/ end=/\]/
    \ contains=@typstMathCodeIn
    \ nextgroup=typstMathCodeBracket
syntax region typstMathCodeParen
    \ contained
    \ start=/(/ end=/)/
    \ contains=@typstMathCodeIn
    \ nextgroup=typstMathCodeParen,typstMathCodeBracket
syntax region typstMathCodeBrace
    \ contained
    \ start=/{/ end=/}/
    \ contains=@typstMathCodeIn
syntax region typstMathCodeBracket
    \ contained
    \ start=/\[/ end=/\]/
    \ contains=@typstMathCodeIn
    \ nextgroup=typstMathCodeBracket
syntax region typstMathCodeString
    \ contained
    \ start=/"/ skip=/\v\\\\|\\"/ end=/"/
syntax cluster typstMathCodeIn
    \ contains=@typstCommon
            \ ,typstMathCodeParen
            \ ,typstMathCodeBrace
            \ ,typstMathCodeBracket
            \ ,typstMathCodeString
            \ ,typstMarkupDollar

" The bundled rule draws the quotes of a string in math as String and leaves
" the text between them without a group.
syntax clear typstMathQuote
syntax region typstMathQuote
    \ contained
    \ start=/"/ skip=/\\"/ end=/"/

highlight default link typstMathCode        Special
highlight default link typstMathHashParen   typstMathCode
highlight default link typstMathHashBrace   typstMathCode
highlight default link typstMathHashBracket typstMathCode
highlight default link typstMathCodeParen   typstMathCode
highlight default link typstMathCodeBrace   typstMathCode
highlight default link typstMathCodeBracket typstMathCode
highlight default link typstMathCodeString  typstMathCode
highlight default link typstMathQuote       typstMathCode


" Raw text. The bundled rules draw the ``` fences with the standard group
" Macro, which no colorscheme can single out. The same two regions, with the
" fences in a group of their own that colors/custom.vim colours like the
" text between them.
syntax clear typstMarkupRawBlock typstMarkupCodeBlockTypst
syntax region typstMarkupRawBlock
    \ matchgroup=typstMarkupRawDelim start=/```\w*/
    \ matchgroup=typstMarkupRawDelim end=/```/ keepend
syntax region typstMarkupCodeBlockTypst
    \ matchgroup=typstMarkupRawDelim start=/```typst/
    \ matchgroup=typstMarkupRawDelim end=/```/ contains=@typstCode keepend
    \ concealends

highlight default link typstMarkupRawDelim Macro


" The bundled rule spell checks strings in code. They are file names, font
" names and keys far more often than prose ("figures/potassium.png" flags
" "png"), so this is the same rule without its contains=@Spell.
syntax clear typstCodeString
syntax region typstCodeString
    \ contained
    \ start=/"/ skip=/\v\\\\|\\"/ end=/"/


" The bundled bold and italic rules are single `syntax match` patterns that
" end at the first * or _ after a non-blank, wherever it falls. In
"   _the functions $J_(0 nu)$, and $h=0$_
" the subscript _ closes the italic, which has already swallowed the opening
" $, so every later $ toggles math out of phase; the trailing $_ then opens
" math that runs on through the following code. Regions don't have this
" problem: Vim never looks for a region's end inside an item nested in it,
" so the _ and * of math, raw text and # expressions are skipped, as in
" Typst itself.
"
" Delimiters follow Typst's lexer: _ and * count unless alphanumerics flank
" them on both sides (snake_case, 2*3) or they are escaped. Like Typst's
" parser, emphasis also stops at the ] of its content block and at a
" paragraph break, so an unclosed delimiter can't spill past either.
syntax clear typstMarkupBold typstMarkupItalic typstMarkupBoldItalic
    \ typstMarkupBoldRegion typstMarkupItalicRegion

" @typstMarkup without the list and heading rules (only meaningful at the
" start of a line) and without bold/italic themselves (added per region).
syntax cluster typstMarkupInline
    \ contains=@typstCommon
            \ ,@Spell
            \ ,@typstHashtag
            \ ,@typstMarkupParens
            \ ,typstMarkupRawInline
            \ ,typstMarkupRawBlock
            \ ,typstMarkupLabel
            \ ,typstMarkupReference
            \ ,typstMarkupUrl
            \ ,typstMarkupLinebreak
            \ ,typstMarkupNonbreakingSpace
            \ ,typstMarkupShy
            \ ,typstMarkupDash
            \ ,typstMarkupEllipsis

syntax region typstMarkupItalic
    \ matchgroup=typstMarkupItalic concealends
    \ start=/\v\\@1<!%(\w@1<!_|_\w@!)/
    \ end=/\v\\@1<!%(\w@1<!_|_\w@!)/ end=/\ze\]/ end=/^\s*$/
    \ contains=@typstMarkupInline,typstMarkupItalicBold
syntax region typstMarkupBold
    \ matchgroup=typstMarkupBold concealends
    \ start=/\v\\@1<!%(\w@1<!\*|\*\w@!)/
    \ end=/\v\\@1<!%(\w@1<!\*|\*\w@!)/ end=/\ze\]/ end=/^\s*$/
    \ contains=@typstMarkupInline,typstMarkupBoldItalic

" Italic inside bold, and bold inside italic.
syntax region typstMarkupBoldItalic
    \ contained
    \ matchgroup=typstMarkupBoldItalic concealends
    \ start=/\v\\@1<!%(\w@1<!_|_\w@!)/
    \ end=/\v\\@1<!%(\w@1<!_|_\w@!)/ end=/\v\ze\\@1<!%(\w@1<!\*|\*\w@!)/ end=/\ze\]/ end=/^\s*$/
    \ contains=@typstMarkupInline
syntax region typstMarkupItalicBold
    \ contained
    \ matchgroup=typstMarkupBoldItalic concealends
    \ start=/\v\\@1<!%(\w@1<!\*|\*\w@!)/
    \ end=/\v\\@1<!%(\w@1<!\*|\*\w@!)/ end=/\v\ze\\@1<!%(\w@1<!_|_\w@!)/ end=/\ze\]/ end=/^\s*$/
    \ contains=@typstMarkupInline

highlight default link typstMarkupItalicBold typstMarkupBoldItalic
