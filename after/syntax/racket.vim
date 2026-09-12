" Layered on $VIMRUNTIME/syntax/racket.vim. Coloured by colors/custom.vim.

" Parse from the top. Upstream syncs with 'grouphere NONE "^[^ \t]"', whose
" match uses up the first character of a column-0 line: parsing restarts just
" past the "(" of "(define", and the define's closing paren is then an
" unmatched racketError. Vim keeps that parse until something invalidates it,
" so a redraw did not clear it; it showed whenever Vim had to resync, such as
" after jumping into a file or after the syntax cache was thrown away.
syntax sync clear
syntax sync fromstart

" The printing procedures and parameters are racketSyntax upstream; they are
" functions like any other, so give them their own group, defined after the
" runtime file so the later keyword wins.
"
" Every group here joins @racketTop rather than using containedin=ALLBUT: that
" cluster is what the racketStruc paren regions contain, so the items reach
" the inside of a form without also being matched inside strings and #| |#.
syntax keyword racketBase write display displayln print fprintf printf eprintf format
syntax keyword racketBase print-pair-curly-braces print-mpair-curly-braces print-unreadable
syntax keyword racketBase print-graph print-struct print-box print-vector-length print-hash-table
syntax keyword racketBase print-boolean-long-form print-reader-abbreviations print-as-expression print-syntax-width
syntax keyword racketBase current-write-relative-directory port-write-handler port-display-handler
syntax keyword racketBase port-print-handler global-port-print-handler
syntax keyword racketBase custodian? custodian-memory-accounting-available? custodian-box?
syntax keyword racketBase make-custodian custodian-shutdown-all current-custodian custodian-managed-list
syntax keyword racketBase custodian-require-memory custodian-limit-memory
syntax keyword racketBase make-custodian-box custodian-box-value

" Calls: the first word after "(", so user functions read like builtins, and
" (define (square x) ...) colours the name it defines. Keywords win over
" matches, so (define and (if keep their groups. Left out: numbers, #t and
" #:kw, quoted words, the _ of a syntax-rules pattern, and the inside of
" #( #hash( and #s( literals, which are data. The binding forms below keep
" bound names from reading as calls.
syntax match racketCall /\%(\%(^\|[^#]\)(\)\@2<=\%([#',]\|[-+]\?\.\?\d\|_\>\)\@!\k\+/ contained

" Parameter lists: after lambda, λ and define-values the words in parens are
" names being bound. Their contents are racketStruc for [y 1] defaults, but
" not racketCall.
syntax keyword racketFormalsForm lambda define-values nextgroup=racketFormals skipwhite skipempty
syntax match racketFormalsForm /\<\%d955\>/ nextgroup=racketFormals skipwhite skipempty
syntax region racketFormals matchgroup=racketParen start=/(/ end=/)/ contained
  \ contains=racketStruc,racketExtSyntax,racketDelimiter,@racketComments

" (struct point (x y)) and (struct child parent (z)): the name is the
" constructor, a function; the fields are formals.
syntax keyword racketStructForm struct define-struct nextgroup=racketStructName skipwhite skipempty
syntax match racketStructName /\k\+/ contained nextgroup=racketStructSuper,racketFormals skipwhite skipempty
syntax match racketStructSuper /\k\+/ contained nextgroup=racketFormals skipwhite skipempty

" Let bindings, both (let ([x 1]) ...) and the SICP style (let ((x 1)) ...):
" the first word of each binding is a name, not a call. A named let's name is
" a function, and let-values binds a formals list.
syntax keyword racketNamedLet let nextgroup=racketLetName,racketBindings skipwhite skipempty
syntax keyword racketLetForm let* letrec let-values let*-values letrec-values
  \ let-syntax letrec-syntax let-syntaxes letrec-syntaxes letrec-syntaxes+values
  \ parameterize parameterize* fluid-let do
  \ nextgroup=racketBindings skipwhite skipempty
syntax match racketLetName /\k\+/ contained nextgroup=racketBindings skipwhite skipempty
syntax region racketBindings matchgroup=racketParen start=/(/ end=/)/ contained
  \ contains=racketBinding,@racketComments
syntax region racketBinding matchgroup=racketParen start=/(/ end=/)/ contained
  \ contains=racketBindingName,racketBindingFormals,@racketTop
syntax region racketBinding matchgroup=racketParen start=/\[/ end=/\]/ contained
  \ contains=racketBindingName,racketBindingFormals,@racketTop
" Defined after racketCall and racketStruc, so at the start of a binding these
" win.
syntax match racketBindingName /\%([([]\)\@1<=\%([#',]\|[-+]\?\.\?\d\)\@!\k\+/ contained
syntax region racketBindingFormals matchgroup=racketParen start=/\%([([]\)\@1<=(/ end=/)/ contained
  \ contains=racketStruc,racketExtSyntax,racketDelimiter,@racketComments

" Quoted data: the quote and every symbol it covers, as in 'return-early and
" '(a b c). Defined after upstream's racketQuote, so the later match wins on
" the quote itself; #' #` and #, stay racketQuote and racketUnquote. Vector,
" hash and prefab literals, #(a b) #hash((k . v)) #s(point 1 2), quote
" themselves, so their contents are data too; their prefix is racketDatumPrefix,
" defined after upstream's racketLit and #( regions so it takes the #. Inside a
" quasiquote, , and ,@ hand the next datum back to code.
syntax match racketQuotedSymbol /\%(#\)\@1<!['`]\%([#',`]\)\@!\k\+/
syntax match racketQuoteMark /\%(#\)\@1<!['`]\ze\%(#\%(hash\%(eqv\?\)\?\|s\)\?\)\?[([{]/
  \ nextgroup=racketDatumPrefix,racketQuotedList
syntax match racketDatumPrefix /#\%(hash\%(eqv\?\)\?\|s\)\?\ze[([{]/ nextgroup=racketQuotedList
syntax region racketQuotedList matchgroup=racketParen start=/(/ end=/)/ contained contains=@racketDatum
syntax region racketQuotedList matchgroup=racketParen start=/\[/ end=/\]/ contained contains=@racketDatum
syntax region racketQuotedList matchgroup=racketParen start=/{/ end=/}/ contained contains=@racketDatum
" \k\@1<! keeps a symbol from starting inside a word, such as the t of #t.
syntax match racketDatumSymbol /\k\@1<!\%([#',`]\|[-+]\?\.\?\d\|\.\>\)\@!\k\+/ contained
syntax match racketDatumUnquote /#\?,@\?/ contained
  \ nextgroup=racketStruc,racketQuotedSymbol,racketQuoteMark,racketDatumPrefix,racketUnquotedWord
syntax match racketUnquotedWord /\%(['`]\)\@!\k\+/ contained
syntax cluster racketDatum contains=racketQuotedList,racketDatumPrefix,racketDatumSymbol,
  \ racketDatumUnquote,racketQuotedSymbol,racketQuoteMark,racketNumber,racketBoolean,
  \ racketChar,racketString,racketHereString,racketExtSyntax,racketDelimiter,@racketComments

" #; comments out the datum after it, so grey the whole datum rather than the
" two characters. The names avoid "comment": vim-sexp takes any such group for
" a comment and would stop moving through the datum's brackets. A datum may
" carry quotes, unquotes and a #, #hash or #s prefix; the lone # of #| is left
" to the block comment. The list's start is a matchgroup so that its own
" bracket cannot also open a nested list.
syntax match racketSkipMark /#;/ nextgroup=racketSkip,racketSkipList,racketSkipString skipwhite skipempty
syntax match racketSkip /\%(#\?['`]\|#\?,@\?\)*\%(#\\\%(\k\+\|.\)\|\%(#|\)\@!\k\+\)/ contained
syntax region racketSkipList matchgroup=racketSkip
  \ start=/\%(#\?['`]\|#\?,@\?\)*\%(#\%(hash\%(eqv\?\)\?\|s\)\?\)\?[([{]/ end=/[)\]}]/ contained
  \ contains=racketSkipList,racketSkipString,racketSkipChar,@racketComments
syntax region racketSkipString start=/\%(#\?['`]\|#\?,@\?\)*\%(#[rp]x#\?\|#\)\?"/
  \ skip=/\\[\\"]/ end=/"/ contained
syntax match racketSkipChar /#\\./ contained

" Syntax forms upstream does not list, which would otherwise read as calls.
syntax keyword racketSyntaxExtra syntax-rules syntax-case syntax-case* syntax-parse
  \ syntax quasisyntax unsyntax unsyntax-splicing with-syntax
  \ only-in except-in prefix-in rename-in combine-in relative-in
  \ for-syntax for-template for-label for-meta
  \ all-defined-out all-from-out rename-out except-out prefix-out struct-out contract-out
  \ define-logger

" #lang with its language.
syntax match racketLang /^#lang\s\+\S\+/

syntax cluster racketTop add=racketBase,racketCall,racketFormalsForm,racketStructForm,
  \ racketNamedLet,racketLetForm,racketQuotedSymbol,racketQuoteMark,racketDatumPrefix,
  \ racketSkipMark,racketSyntaxExtra

highlight default link racketBase racketFunc
highlight default link racketCall racketFunc
highlight default link racketStructName racketFunc
highlight default link racketLetName racketFunc
highlight default link racketFormalsForm racketSyntax
highlight default link racketStructForm racketSyntax
highlight default link racketNamedLet racketSyntax
highlight default link racketLetForm racketSyntax
highlight default link racketQuotedSymbol Constant
highlight default link racketQuoteMark racketQuotedSymbol
highlight default link racketDatumSymbol racketQuotedSymbol
highlight default link racketDatumUnquote racketUnquote
highlight default link racketSkipMark Comment
highlight default link racketSkip Comment
highlight default link racketSkipList racketSkip
highlight default link racketSkipString racketSkip
highlight default link racketSkipChar racketSkip
highlight default link racketDatumPrefix racketLit
highlight default link racketSyntaxExtra racketSyntax
highlight default link racketLang PreProc
