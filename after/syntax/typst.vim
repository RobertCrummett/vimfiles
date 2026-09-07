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
