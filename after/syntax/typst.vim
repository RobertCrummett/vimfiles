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
