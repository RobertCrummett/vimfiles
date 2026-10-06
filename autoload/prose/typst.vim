" prose, for Typst: which parts of a document are not prose. The marking of
" buffers is in autoload/prose.vim, which calls prose#typst#run(). See :help
" prose-typst.
"
" What is code is decided here and not by the syntax file. The bundled
" syntax recognises code with regular expressions, which get it wrong in
" both directions: the prose of a caption inside #figure(caption: [...])
" counts as code, and the body of "#show x: it => {" spread over several
" lines counts as prose. The scanner follows Typst's own lexer and parser
" (typst-syntax 0.15, lexer.rs and parser.rs) instead, for exactly the part
" that settles where code starts and stops:
"
"   markup    prose, apart from: "#" and the expression after it, $math$,
"             `raw text`, <labels> and @references
"   code      everything up to the end of the expression. Between ( ) and
"             { } that is simply the matching delimiter. After a bare "#" it
"             takes Typst's grammar: "#f(x)[y].z" stops where the calls and
"             fields stop, "#let x = 1 + 2" at the end of the line, "#if a
"             {..} else {..}" after the last block, and so on.
"   [ ]       a content block inside code is markup again
"   comments  neither: they keep the colour the syntax file gives them
"
" Not followed: Typst restarts its count of open "[" inside emphasis,
" headings and list items, so a bracket opened in one and closed outside it
" pairs up differently there; here every "[" in a content block pairs with
" the next free "]". Non-ASCII letters count as identifier characters and the
" usual blocks of non-ASCII punctuation do not, which is close to but not
" the same as Unicode's XID classes.
"
" The text is a list of lines, s:L, and the cursor a line index and a byte
" offset in it, both from 0: one long string would be simpler, but every
" index and match() on it costs Vim a pass over the whole string.

" The last number given to a frame, and the most lines one go may cover.
let s:serial = 0
let s:span = 0

let s:hi = '[^\x00-\x7f -¿×÷ -⁯←-⇿∀-⋿　-〿]'
let s:id1 = '\%([A-Za-z_]\|' . s:hi . '\)'
let s:idn = '\%([A-Za-z0-9_-]\|' . s:hi . '\)'
let s:p_id1 = '^' . s:id1
let s:p_idn = '^' . s:idn
let s:p_ident = '^' . s:id1 . s:idn . '*'
" Labels and references may also hold "." and ":".
let s:p_label = '^\%([A-Za-z0-9_.:-]\|' . s:hi . '\)*'
let s:p_space = '^[ \t\r\x0b\x0c\u0085   -     　]*'

" Where something other than text may start: in markup, between the
" delimiters of code, and in math.
let s:p_markup = '\C[\\#$\[\]`<@]\|https\=://\|//\|/\*\|\*/'
let s:p_code = '[][(){};"`$/]'
let s:p_math = '[$#"\\/]\|\*/'

" Words that are not identifiers, with the kind of token they make.
let s:words = {'true': 'lit', 'false': 'lit'}
for s:w in ['not', 'and', 'or', 'none', 'auto', 'let', 'set', 'show', 'context', 'if', 'else',
      \ 'for', 'in', 'while', 'break', 'continue', 'return', 'import', 'include', 'as']
  let s:words[s:w] = s:w
endfor
unlet s:w
let s:keywords = filter(copy(s:words), 'v:val !=# "lit"')

function! s:Set(...) abort
  let l:d = {}
  for l:k in a:000
    let l:d[l:k] = 1
  endfor
  return l:d
endfunction

let s:two = s:Set('==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '..', '=>')
let s:unary = s:Set('+', '-', 'not')
let s:binary = s:Set('+', '-', '*', '/', 'and', 'or', '==', '!=', '<', '<=', '>', '>=', '=', 'in',
      \ '+=', '-=', '*=', '/=')
" Tokens an expression can start with, when it may not start with an
" operator (Typst's ATOMIC_CODE_EXPR).
let s:atom = s:Set('ident', '{', '[', '(', '$', 'let', 'set', 'show', 'context', 'if', 'while',
      \ 'for', 'import', 'include', 'break', 'continue', 'return', 'none', 'auto', 'lit')
" Statements: after "#" they run to the end of the line or a ";".
let s:stmt = s:Set('let', 'set', 'show', 'import', 'include', 'return')
let s:closers = s:Set('end', ';', '}', ')', ']')
let s:units = ['', 'pt', 'mm', 'cm', 'in', 'deg', 'rad', 'em', 'fr', '%']

" ----- the cursor, and the code found so far

function! s:Goto(l, c) abort
  let s:ln = a:l
  let s:col = a:c
  let s:line = get(s:L, a:l, '')
endfunction

" To the start of the next line, inside something that spans lines. That
" cannot be left half done, so when it has taken longer than the scan may
" (s:cap) the scan is given up. (Asking whether a key is waiting would be
" kinder, but getchar(1) from a timer loses the key it sees.)
function! s:Down() abort
  let s:ln += 1
  let s:col = 0
  let s:line = get(s:L, s:ln, '')
  let s:ticks += 1
  if s:cap > 0 && s:ticks % 8 == 0 && reltimefloat(reltime(s:began)) > s:cap
    throw 'prose-abort'
  endif
endfunction

" The same check, every so many lines, for a comment, raw text or a string
" that runs on and on: a:l is the line it has come to.
function! s:Long(l) abort
  if s:cap > 0 && a:l % 64 == 0 && reltimefloat(reltime(s:began)) > s:cap
    throw 'prose-abort'
  endif
endfunction

" ----- where a scan can stop, and start again
"
" A scan is at home in two kinds of place, where what comes next does not
" depend on how it got there:
"   markup   that of the document, or of a content block [..]. All there is
"            to know is how many "[" of the text are open.
"   a group  the code between ( ) or { }. All there is to know is which
"            closing delimiters are awaited.
" Each content block and each group that the grammar opens is a frame, with a
" number of its own, for good; the document is frame 0. When a frame comes
" to the start of a line, a scan started at that line, knowing only the
" frame and that little, finds what the whole scan would. Such a line is
" "arrived at", and gets a flag:
"   0                    not arrived at: inside something else
"   1                    in the markup of the document
"   1000 * frame + code  in that frame; code is the number of open "[" plus
"                        2 in markup, and in a group stands for the
"                        delimiters awaited (see s:Code())
" s:blocks holds for each frame that spans lines [parent, code, kind,
" stacks]: the frame it was opened in and the code of that frame at the
" time; what follows its end; and for a group the lists of delimiters that
" its codes stand for (for a content block, 0). The kinds:
"   1  opened by the expression that follows a "#" in markup at once:
"      "#[..]", "#name[..]", "#f(..)". After it come more arguments or
"      fields, then the markup goes on.
"   2  the supplement of a "@reference": the markup goes on.
"   3  a content block right inside a group: the group goes on.
"   0  anything else, such as the "{" in "#let f(x) = {": what follows is in
"      the middle of a statement, which a scan cannot enter.
" The frame of a scan is the one it can stop in: the frame it started in; a
" frame of kind 1 to 3 that this one opens at the end of a line (the scan
" then moves into it); and, when such a frame ends, the one it was opened in.

" What the innermost frame knows at this point, as a number: the code part
" of a flag. 0 if there is no number for it.
function! s:Code() abort
  if s:frame == 0
    return 1
  elseif !s:isgroup
    return s:nest > 900 ? 0 : s:nest + 2
  endif
  " The delimiters awaited, as a string, are given numbers as they turn up.
  let l:known = s:blocks[s:frame][3]
  let l:key = join(s:stack, '')
  let l:i = index(l:known, l:key)
  if l:i < 0
    if len(l:known) > 900
      return 0
    endif
    call add(l:known, l:key)
    let l:i = len(l:known) - 1
  endif
  return l:i + 1
endfunction

" The innermost frame has come to the start of line s:ln. In the frame of
" the scan this is where it can stop, and returns 1 to say so: when the
" lines from here on were scanned from this same place last time and have
" not changed since (s:safe, s:hi), or when one go has had its time
" (s:budget) or its lines (s:span).
function! s:Arrive() abort
  if s:ln >= s:nl
    return 0
  endif
  let l:code = s:Code()
  if !l:code
    return 0
  endif
  let l:flag = s:frame * 1000 + l:code
  if s:frame == s:live
    " In a group the code runs on over the line break: cut it here, so that
    " what has been found so far is whole.
    call s:CloseAt(s:ln, 0)
    if s:ln > s:hi && s:safe[s:ln] == l:flag
      let [s:end, s:stopped] = [s:ln, 1]
      return 1
    elseif s:budget > 0 && (s:ln - s:origin >= s:span || reltimefloat(reltime(s:began)) > s:budget)
      let [s:end, s:endflag, s:more, s:stopped] = [s:ln, l:flag, 1, 1]
      return 1
    endif
    if s:isgroup
      call s:OpenAt(s:ln, 0)
    endif
    let s:at = [s:ln, l:flag]
  endif
  call add(s:arrive, [s:ln, l:flag])
  return 0
endfunction

" Code is collected as stretches: opened where it starts, closed where it
" stops, and cut into one [lnum, col, lnum, end] per line for
" prop_add_list(). Opening an open stretch or closing a closed one does
" nothing, so the pieces of an expression need not know about each other.
function! s:OpenAt(l, c) abort
  if empty(s:from)
    let s:from = [a:l, a:c]
  endif
endfunction

function! s:CloseAt(l, c) abort
  if empty(s:from)
    return
  endif
  let [l:l, l:c] = s:from
  let s:from = []
  while l:l < a:l
    let l:end = len(s:L[l:l])
    if l:end > l:c
      call add(s:out, [l:l + 1, l:c + 1, l:l + 1, l:end + 1])
    endif
    let l:l += 1
    let l:c = 0
  endwhile
  if a:c > l:c
    call add(s:out, [l:l + 1, l:c + 1, l:l + 1, a:c + 1])
  endif
endfunction

" ----- pieces that are the same in every mode

" The position after the block comment that starts at a:l, a:c. They nest.
function! s:BlockEnd(l, c) abort
  let l:l = a:l
  let l:c = a:c + 2
  let l:depth = 1
  while l:l < s:nl
    let l:j = match(s:L[l:l], '\*/\|/\*', l:c)
    if l:j < 0
      let l:l += 1
      let l:c = 0
      call s:Long(l:l)
      continue
    endif
    let l:depth += s:L[l:l][l:j] ==# '*' ? -1 : 1
    let l:c = l:j + 2
    if l:depth == 0
      return [l:l, l:c]
    endif
  endwhile
  return [s:nl, 0]
endfunction

" The raw text whose first backtick is at a:l, a:c, as a token. `` is empty
" raw text; otherwise it runs to as many backticks as it opened with, and
" one that is never closed takes the rest of the document with it.
function! s:Raw(l, c) abort
  let l:count = matchend(s:L[a:l], '^`\+', a:c) - a:c
  if l:count == 2
    return ['lit', a:l, a:c + 2]
  endif
  let l:l = a:l
  let l:c = a:c + l:count
  while l:l < s:nl
    let l:e = matchend(s:L[l:l], '`\{' . l:count . '}', l:c)
    if l:e >= 0
      return ['lit', l:l, l:e]
    endif
    let l:l += 1
    let l:c = 0
    call s:Long(l:l)
  endwhile
  return ['error', s:nl, 0]
endfunction

" The string whose opening quote is at a:l, a:c, as a token.
function! s:String(l, c) abort
  let l:l = a:l
  let l:c = a:c + 1
  while l:l < s:nl
    let l:j = match(s:L[l:l], '["\\]', l:c)
    if l:j < 0
      let l:l += 1
      let l:c = 0
      call s:Long(l:l)
    elseif s:L[l:l][l:j] ==# '"'
      return ['lit', l:l, l:j + 1]
    elseif l:j + 1 >= len(s:L[l:l])
      " A backslash at the end of the line escapes the line break.
      let l:l += 1
      let l:c = 0
    else
      let l:c = l:j + 2
    endif
  endwhile
  return ['error', s:nl, 0]
endfunction

" The column after the backslash escape at the cursor (markup and math).
function! s:Escape() abort
  let l:e = matchend(s:line, '^\\u{[0-9A-Za-z]*}\=', s:col)
  if l:e < 0
    let l:e = matchend(s:line, '^\\.', s:col)
  endif
  return l:e < 0 ? s:col + 1 : l:e
endfunction

" At a "/" in code or math. A comment is stepped over and left out of the
" code around it; anything else is one more character of it.
function! s:Slash() abort
  let l:two = strpart(s:line, s:col, 2)
  if l:two ==# '//'
    call s:CloseAt(s:ln, s:col)
    let s:col = len(s:line)
  elseif l:two ==# '/*'
    call s:CloseAt(s:ln, s:col)
    let [l:l, l:c] = s:BlockEnd(s:ln, s:col)
    call s:Goto(l:l, l:c)
  else
    let s:col += 1
    return
  endif
  call s:OpenAt(s:ln, s:col)
endfunction

" ----- markup

" Markup from the cursor to the end of the text or, in a content block, to
" the "]" that closes it, which is left for the caller. a:frame is the
" block's number, 0 for the document, and a:nesting the "[" of the text that
" are open at the cursor; both are kept in s:frame and s:nest, for
" s:Arrive() and for the blocks opened from here. Also returns, with
" s:stopped set, when the scan is to stop at the line it has come to.
function! s:Markup(frame, nesting) abort
  let [s:frame, s:isgroup, s:nest] = [a:frame, 0, a:nesting]
  while s:ln < s:nl
    let l:j = match(s:line, s:p_markup, s:col)
    if l:j < 0
      if s:Newline()
        return
      endif
      continue
    endif
    let s:col = l:j
    let l:ch = s:line[l:j]
    if l:ch ==# '#'
      if l:j == 0 && s:ln == 0 && s:line[1] ==# '!'
        " A "#!" line at the very top is for the shell.
        call s:OpenAt(0, 0)
        let s:col = len(s:line)
        call s:CloseAt(0, s:col)
      else
        call s:Embedded()
      endif
    elseif l:ch ==# '$'
      call s:Equation()
    elseif l:ch ==# '@'
      if match(s:line, s:p_idn, l:j + 1) < 0
        let s:col += 1
        continue
      endif
      " A reference, less the "." or ":" a sentence may end it with, and
      " with its supplement when a "[" follows at once.
      let l:e = matchend(s:line, s:p_label, l:j + 1)
      while s:line[l:e - 1] ==# '.' || s:line[l:e - 1] ==# ':'
        let l:e -= 1
      endwhile
      call s:OpenAt(s:ln, l:j)
      let s:col = l:e
      if s:line[l:e] ==# '['
        call s:Content(2)
      endif
      call s:CloseAt(s:ln, s:col)
    elseif l:ch ==# '<'
      if match(s:line, s:p_idn, l:j + 1) < 0
        let s:col += 1
        continue
      endif
      " A label when it is closed; otherwise an error, which stays prose.
      let l:e = matchend(s:line, s:p_label, l:j + 1)
      if s:line[l:e] ==# '>'
        call s:OpenAt(s:ln, l:j)
        call s:CloseAt(s:ln, l:e + 1)
        let l:e += 1
      endif
      let s:col = l:e
    elseif l:ch ==# '['
      let s:nest += 1
      let s:col += 1
    elseif l:ch ==# ']'
      if s:nest > 0
        let s:nest -= 1
      elseif s:frame != 0
        return
      endif
      let s:col += 1
    elseif l:ch ==# '\'
      let s:col = s:Escape()
    elseif l:ch ==# '`'
      let [l:kind, l:l, l:c] = s:Raw(s:ln, l:j)
      if l:kind ==# 'lit'
        call s:OpenAt(s:ln, l:j)
        call s:CloseAt(l:l, l:c)
      endif
      call s:Goto(l:l, l:c)
    elseif l:ch ==# 'h'
      let s:col = s:LinkEnd(matchend(s:line, '^\Chttps\=://', l:j))
    elseif l:ch ==# '*'
      " A stray "*/".
      let s:col += 2
    elseif s:line[l:j + 1] ==# '/'
      let s:col = len(s:line)
    else
      let [l:l, l:c] = s:BlockEnd(s:ln, l:j)
      call s:Goto(l:l, l:c)
    endif
  endwhile
endfunction

" The column where the link whose address starts at a:c ends, as Typst's
" link_prefix() has it: brackets must pair up, and punctuation at the end
" belongs to the sentence.
function! s:LinkEnd(c) abort
  let l:e = matchend(s:line, '^[0-9A-Za-z!#$%&*+,./:;=?@_~''()\[\]-]*', a:c)
  let l:open = []
  let l:j = a:c
  while 1
    let l:j = match(s:line, '[][()]', l:j)
    if l:j < 0 || l:j >= l:e
      break
    endif
    let l:ch = s:line[l:j]
    if l:ch ==# '[' || l:ch ==# '('
      call add(l:open, l:ch)
    elseif empty(l:open) || remove(l:open, -1) !=# (l:ch ==# ']' ? '[' : '(')
      let l:e = l:j
      break
    endif
    let l:j += 1
  endwhile
  return a:c + match(strpart(s:line, a:c, l:e - a:c), '[!,.:;?'']*$')
endfunction

" A content block: its brackets are code, what they hold is markup again.
" The cursor is on the "[" and is left after the "]". The stretch of code
" that is open on entry is open again on return. a:kind is the kind of frame
" it is (see s:blocks) unless it is in the middle of something.
function! s:Content(kind) abort
  let s:col += 1
  call s:CloseAt(s:ln, s:col)
  let l:id = s:Frame(a:kind, 0)
  let l:open = s:ln
  let l:keep = [s:frame, s:isgroup, s:nest, s:stack, s:complex]
  let s:complex = 0
  call s:Markup(l:id, 0)
  let [s:frame, s:isgroup, s:nest, s:stack, s:complex] = l:keep
  if s:ln == l:open
    " Within one line: no scan will ever start inside it.
    call remove(s:blocks, l:id)
  endif
  call s:OpenAt(s:ln, s:col)
  if s:ln < s:nl
    let s:col += 1
  endif
endfunction

" A new frame opens after the cursor: give it a number and record it.
" a:stacks is what s:blocks keeps as such.
function! s:Frame(kind, stacks) abort
  let s:serial += 1
  let l:code = s:Code()
  let s:blocks[s:serial] = [s:frame, l:code, s:complex || !l:code ? 0 : a:kind, a:stacks]
  return s:serial
endfunction

" The innermost frame is at the end of a line: on to the next one. In the
" frame of the scan that is a place to stop, and returns 1 to say so.
" Elsewhere a frame may only now turn out to span lines: if what follows it,
" and each frame from there out to the frame of the scan, is known (a kind
" other than 0), nothing on the way here has to be come back to, and the
" scan moves into it, so that it can stop inside from here on. s:Scan()
" catches the exception and takes over.
function! s:Newline() abort
  if s:frame == s:live
    call s:Goto(s:ln + 1, 0)
    return s:Arrive()
  endif
  let l:f = s:frame
  while l:f != s:live && l:f != 0 && s:blocks[l:f][2]
    let l:f = s:blocks[l:f][0]
  endwhile
  if l:f == s:live
    let l:code = s:Code()
    if l:code
      let [s:into, s:intocode] = [s:frame, l:code]
      throw 'prose-into'
    endif
  endif
  call s:Down()
  call s:Arrive()
  return 0
endfunction

" An equation, from the "$" under the cursor to the one that closes it.
function! s:Equation() abort
  let l:was = !empty(s:from)
  let s:complex += 1
  call s:OpenAt(s:ln, s:col)
  let s:col += 1
  while s:ln < s:nl
    let l:j = match(s:line, s:p_math, s:col)
    if l:j < 0
      call s:Down()
      continue
    endif
    let s:col = l:j
    let l:ch = s:line[l:j]
    if l:ch ==# '$'
      let s:col += 1
      break
    elseif l:ch ==# '#'
      call s:Embedded()
    elseif l:ch ==# '"'
      let [l:kind, l:l, l:c] = s:String(s:ln, l:j)
      call s:Goto(l:l, l:c)
    elseif l:ch ==# '\'
      let s:col = s:Escape()
    elseif l:ch ==# '*'
      let s:col += 2
    else
      call s:Slash()
    endif
  endwhile
  let s:complex -= 1
  if !l:was
    call s:CloseAt(s:ln, s:col)
  endif
endfunction

" ----- code between delimiters

" Between ( ) and { } there is nothing to decide: it is all code up to the
" closing delimiter, apart from comments and the markup of content blocks.
" a:frame is the group's number and a:stack the closing delimiters awaited,
" the innermost last; the cursor is inside the group and is left after its
" closing delimiter. As in Typst, a closing delimiter of the wrong kind ends
" the group it is in without belonging to it, and so does a ";" between
" parentheses. Also returns, with s:stopped set, when the scan is to stop
" at the line it has come to.
function! s:Group(frame, stack) abort
  let l:stack = a:stack
  let [s:frame, s:isgroup, s:stack] = [a:frame, 1, l:stack]
  while s:ln < s:nl && !empty(l:stack)
    let l:j = match(s:line, s:p_code, s:col)
    if l:j < 0
      if s:Newline()
        return
      endif
      continue
    endif
    let s:col = l:j
    let l:ch = s:line[l:j]
    if l:ch ==# l:stack[-1]
      let s:col += 1
      call remove(l:stack, -1)
    elseif l:ch ==# '('
      let s:col += 1
      call add(l:stack, ')')
    elseif l:ch ==# '{'
      let s:col += 1
      call add(l:stack, '}')
    elseif l:ch ==# '['
      call s:Content(3)
    elseif l:ch ==# ')' || l:ch ==# '}' || l:ch ==# ']' || (l:ch ==# ';' && l:stack[-1] ==# ')')
      call remove(l:stack, -1)
    elseif l:ch ==# ';'
      let s:col += 1
    elseif l:ch ==# '"'
      let [l:kind, l:l, l:c] = s:String(s:ln, l:j)
      call s:Goto(l:l, l:c)
    elseif l:ch ==# '`'
      let [l:kind, l:l, l:c] = s:Raw(s:ln, l:j)
      call s:Goto(l:l, l:c)
    elseif l:ch ==# '$'
      call s:Equation()
    else
      call s:Slash()
    endif
  endwhile
endfunction

" A group that the grammar opens, the cursor on its "(" or "{".
function! s:Open() abort
  let l:close = s:line[s:col] ==# '(' ? ')' : '}'
  let s:col += 1
  let l:id = s:Frame(1, [l:close])
  let l:open = s:ln
  let l:keep = [s:frame, s:isgroup, s:nest, s:stack, s:complex]
  let s:complex = 0
  call s:Group(l:id, [l:close])
  let [s:frame, s:isgroup, s:nest, s:stack, s:complex] = l:keep
  if s:ln == l:open
    call remove(s:blocks, l:id)
  endif
endfunction

" ----- the expression after a "#"
"
" Tokens are needed only here, where no delimiter says how far the code
" goes. s:tok is the token after the cursor, which itself stays at the end
" of the last token taken:
"   kind       the token's text for operators, delimiters and keywords;
"              otherwise 'ident', '_', 'lit' (a value by itself: a number,
"              string, label, raw text, true, false), 'error' or 'end'
"   l, c       where it starts, and el, ec where it ends
"   direct     nothing between the cursor and it, not even a space
"   comments   the comments skipped on the way to it
" A line break ends the expression, so a token on a later line is an 'end'.

function! s:Lex(stop) abort
  let l:l = s:ln
  let l:c = s:col
  let l:comments = []
  let l:kind = ''
  while 1
    if l:l >= s:nl
      let [l:kind, l:l, l:c] = ['end', s:nl, 0]
      break
    endif
    let l:line = s:L[l:l]
    let l:c = matchend(l:line, s:p_space, l:c)
    if l:c >= len(l:line)
      if a:stop
        let l:kind = 'end'
        break
      endif
      let l:l += 1
      let l:c = 0
    elseif l:line[l:c] ==# '/' && l:line[l:c + 1] ==# '/'
      call add(l:comments, [l:l, l:c, l:l, len(l:line)])
      let l:c = len(l:line)
    elseif l:line[l:c] ==# '/' && l:line[l:c + 1] ==# '*'
      let [l:el, l:ec] = s:BlockEnd(l:l, l:c)
      call add(l:comments, [l:l, l:c, l:el, l:ec])
      let [l:l, l:c] = [l:el, l:ec]
    else
      break
    endif
  endwhile
  let [l:kind, l:el, l:ec] = l:kind ==# 'end' ? ['end', l:l, l:c] : s:Token(l:l, l:c)
  let s:tok = {'kind': l:kind, 'l': l:l, 'c': l:c, 'el': l:el, 'ec': l:ec,
        \ 'direct': l:l == s:ln && l:c == s:col, 'comments': l:comments}
endfunction

" The token of code at a:l, a:c: [kind, line, column after it].
function! s:Token(l, c) abort
  let l:line = s:L[a:l]
  let l:ch = l:line[a:c]
  let l:two = strpart(l:line, a:c, 2)
  if l:two ==# '*/'
    return ['error', a:l, a:c + 2]
  elseif l:ch ==# '`'
    return s:Raw(a:l, a:c)
  elseif l:ch ==# '<' && match(l:line, s:p_idn, a:c + 1) >= 0
    let l:e = matchend(l:line, s:p_label, a:c + 1)
    return l:line[l:e] ==# '>' ? ['lit', a:l, l:e + 1] : ['error', a:l, l:e]
  elseif l:ch =~# '[0-9]' || (l:ch ==# '.' && l:line[a:c + 1] =~# '[0-9]')
    return s:Number(a:l, a:c)
  elseif l:ch ==# '"'
    return s:String(a:l, a:c)
  elseif has_key(s:two, l:two)
    return [l:two, a:l, a:c + 2]
  elseif stridx('{}[]()$,;:.+-*/=<>', l:ch) >= 0
    return [l:ch, a:l, a:c + 1]
  elseif strpart(l:line, a:c, 3) ==# "−"
    " The minus sign proper is a minus too.
    return l:line[a:c + 3] ==# '=' ? ['-=', a:l, a:c + 4] : ['-', a:l, a:c + 3]
  endif
  let l:e = matchend(l:line, s:p_ident, a:c)
  if l:e < 0
    " Not something code can hold.
    let l:pair = l:two ==# '&&' || l:two ==# '||' || l:two ==# '~='
    return ['error', a:l, l:pair ? a:c + 2 : matchend(l:line, '^.', a:c)]
  endif
  let l:word = strpart(l:line, a:c, l:e - a:c)
  if has_key(s:words, l:word)
    " A keyword, unless it is a field or a method: "x.in", but "..in" is.
    let l:before = a:c > 0 ? l:line[a:c - 1] : ''
    if l:before !=# '@' && (l:before !=# '.' || (a:c > 1 && l:line[a:c - 2] ==# '.'))
      return [s:words[l:word], a:l, l:e]
    endif
  endif
  return [l:word ==# '_' ? '_' : 'ident', a:l, l:e]
endfunction

" A number as Typst lexes it: an integer in base 2, 8, 10 or 16, or a float,
" then a unit. One that is malformed is an error, but just as long.
function! s:Number(l, c) abort
  let l:line = s:L[a:l]
  let l:j = a:c + 1
  let l:base = 10
  if l:line[a:c] ==# '0' && l:line[l:j] =~# '^[box]$'
    let l:base = l:line[l:j] ==# 'x' ? 16 : l:line[l:j] ==# 'o' ? 8 : 2
    let l:j += 1
  endif
  let l:j = matchend(l:line, l:base == 16 ? '^[0-9A-Za-z]*' : '^[0-9]*', l:j)
  if l:base != 10
    let l:digits = strpart(l:line, a:c + 2, l:j - a:c - 2)
    let l:e = matchend(l:line, '^[0-9A-Za-z%]*', l:j)
    let l:ok = l:e == l:j && l:digits =~# (l:base == 16 ? '^\x\+$' : l:base == 8 ? '^[0-7]\+$' : '^[01]\+$')
    return [l:ok ? 'lit' : 'error', a:l, l:e]
  endif
  " A "." is the decimal point unless it starts a spread or a method call.
  if l:line[a:c] !=# '.' && l:line[l:j] ==# '.' && l:line[l:j + 1] !=# '.' && match(l:line, s:p_id1, l:j + 1) < 0
    let l:j = matchend(l:line, '^[0-9]*', l:j + 1)
  endif
  let l:ok = 1
  if l:line[l:j] =~# '^[eE]$' && strpart(l:line, l:j, 2) !=# 'em'
    let l:sign = matchend(l:line, '^[+-]\=', l:j + 1)
    let l:j = matchend(l:line, '^[0-9]*', l:sign)
    let l:ok = l:j > l:sign
  endif
  let l:e = matchend(l:line, '^[0-9A-Za-z%]*', l:j)
  let l:ok = l:ok && index(s:units, strpart(l:line, l:j, l:e - l:j)) >= 0
  return [l:ok ? 'lit' : 'error', a:l, l:e]
endfunction

" Move onto the current token. Comments passed on the way are inside the
" expression, but not code.
function! s:Take() abort
  for l:x in s:tok.comments
    call s:CloseAt(l:x[0], l:x[1])
    call s:OpenAt(l:x[2], l:x[3])
  endfor
  call s:Goto(s:tok.l, s:tok.c)
endfunction

function! s:Eat() abort
  call s:Take()
  call s:Goto(s:tok.el, s:tok.ec)
  call s:Lex(1)
endfunction

" Typst's expected(): where something is missing nothing is taken, except a
" token that is an error anyway.
function! s:Expected() abort
  if s:tok.kind ==# 'error'
    call s:Eat()
  endif
endfunction

" Typst's expect(): a keyword where an identifier belongs is taken as one.
function! s:Expect(kind) abort
  if s:tok.kind ==# a:kind || (a:kind ==# 'ident' && has_key(s:keywords, s:tok.kind))
    call s:Eat()
  else
    call s:Expected()
  endif
endfunction

" The current token opens something that is scanned rather than parsed.
function! s:Block() abort
  call s:Take()
  let l:ch = s:line[s:col]
  if l:ch ==# '['
    call s:Content(1)
  elseif l:ch ==# '$'
    call s:Equation()
  else
    call s:Open()
  endif
  call s:Lex(1)
endfunction

" A "#" in markup or math and the expression after it. The cursor is on the
" "#" and is left at the end of the expression.
function! s:Embedded() abort
  let l:was = !empty(s:from)
  call s:OpenAt(s:ln, s:col)
  let s:col += 1
  call s:Lex(1)
  if s:tok.direct && s:tok.kind !=# 'end'
    let l:stmt = has_key(s:stmt, s:tok.kind)
    call s:Expr(1)
    if s:tok.kind ==# ';' ? (l:stmt || s:tok.direct) : (l:stmt && s:tok.kind ==# 'error')
      call s:Eat()
    endif
  endif
  if !l:was
    call s:CloseAt(s:ln, s:col)
  endif
endfunction

" Typst's code_expr_prec(), without the precedences: they decide how an
" expression nests, not how far it goes. a:atomic is for the expression
" right after a "#", which takes calls and fields but no operators, so that
" "#x + 1" leaves "+ 1" to the text.
function! s:Expr(atomic) abort
  " s:complex counts what a content block opened from here would be in the
  " middle of. Only in the expression right after a "#" is that nothing.
  let s:complex += !a:atomic
  if has_key(s:unary, s:tok.kind)
    call s:Eat()
    if !a:atomic
      call s:Expr(0)
    endif
  else
    call s:Primary(a:atomic)
  endif
  call s:Postfix(a:atomic)
  let s:complex -= !a:atomic
endfunction

" What may follow a value: arguments, fields, and unless a:atomic, operators
" with their right-hand sides.
function! s:Postfix(atomic) abort
  while 1
    let l:kind = s:tok.kind
    if s:tok.direct && (l:kind ==# '(' || l:kind ==# '[')
      call s:Args()
      continue
    endif
    if a:atomic
      " Only ".name" may follow, with nothing in between.
      let l:word = l:kind ==# '.' && s:tok.direct ? matchstr(s:L[s:tok.el], s:p_ident, s:tok.ec) : ''
      if l:word ==# '' || l:word ==# '_'
        return
      endif
    endif
    if l:kind ==# '.'
      call s:Eat()
      call s:Expect('ident')
    elseif has_key(s:binary, l:kind)
      call s:Eat()
      call s:Expr(0)
    elseif l:kind ==# 'not'
      call s:Eat()
      if s:tok.kind !=# 'in'
        call s:Expected()
        return
      endif
      call s:Eat()
      call s:Expr(0)
    else
      return
    endif
  endwhile
endfunction

function! s:Primary(atomic) abort
  let l:kind = s:tok.kind
  if l:kind ==# 'ident'
    call s:Eat()
    if !a:atomic && s:tok.kind ==# '=>'
      call s:Eat()
      call s:Expr(0)
    endif
  elseif l:kind ==# '_' && !a:atomic
    call s:Eat()
    if s:tok.kind ==# '=>' || s:tok.kind ==# '='
      call s:Eat()
      call s:Expr(0)
    endif
  elseif l:kind ==# '('
    call s:Block()
    " Parameters after all: a closure. ("(a, b) = c" needs no such care,
    " "=" being an operator.)
    if !a:atomic && s:tok.kind ==# '=>'
      call s:Eat()
      call s:Expr(0)
    endif
  elseif l:kind ==# '{' || l:kind ==# '[' || l:kind ==# '$'
    call s:Block()
  elseif l:kind ==# 'lit' || l:kind ==# 'none' || l:kind ==# 'auto' || l:kind ==# 'break' || l:kind ==# 'continue'
    call s:Eat()
  else
    " A statement: a block in it has the rest of the statement after it.
    let s:complex += 1
    call s:Statement(l:kind, a:atomic)
    let s:complex -= 1
  endif
endfunction

function! s:Statement(kind, atomic) abort
  let l:kind = a:kind
  if l:kind ==# 'let'
    call s:Eat()
    let l:must = 1
    if s:tok.kind ==# 'ident'
      call s:Eat()
      let l:must = s:tok.direct && s:tok.kind ==# '('
      if l:must
        call s:Block()
      endif
    else
      call s:Pattern()
    endif
    if s:tok.kind ==# '='
      call s:Eat()
      call s:Expr(0)
    elseif l:must
      call s:Expected()
    endif
  elseif l:kind ==# 'set'
    call s:Eat()
    call s:Expect('ident')
    while s:tok.kind ==# '.'
      call s:Eat()
      call s:Expect('ident')
    endwhile
    if !s:tok.direct || (s:tok.kind !=# '(' && s:tok.kind !=# '[')
      call s:Expected()
    endif
    call s:Args()
    if s:tok.kind ==# 'if'
      call s:Eat()
      call s:Expr(0)
    endif
  elseif l:kind ==# 'show'
    call s:Eat()
    if s:tok.kind !=# ':'
      call s:Expr(0)
    endif
    if s:tok.kind ==# ':'
      call s:Eat()
      call s:Expr(0)
    endif
  elseif l:kind ==# 'context'
    call s:Eat()
    call s:Expr(a:atomic)
  elseif l:kind ==# 'if'
    call s:If()
  elseif l:kind ==# 'while'
    call s:Eat()
    call s:Expr(0)
    call s:Body()
  elseif l:kind ==# 'for'
    call s:Eat()
    call s:Pattern()
    if s:tok.kind ==# ','
      call s:Eat()
      if has_key(s:atom, s:tok.kind) || s:tok.kind ==# '_'
        call s:Pattern()
      endif
    endif
    call s:Expect('in')
    call s:Expr(0)
    call s:Body()
  elseif l:kind ==# 'import'
    call s:Import()
  elseif l:kind ==# 'include'
    call s:Eat()
    call s:Expr(0)
  elseif l:kind ==# 'return'
    call s:Eat()
    if has_key(s:atom, s:tok.kind) || has_key(s:unary, s:tok.kind) || s:tok.kind ==# '_'
      call s:Expr(0)
    endif
  elseif a:atomic
    " Whatever is there is taken, as an error: "#]", "#12p". After "#context"
    " that reaches the first token of the next line.
    if l:kind ==# 'end'
      call s:Lex(0)
    endif
    call s:Eat()
  else
    call s:Expected()
  endif
endfunction

" The arguments of a call: (...) and then any number of [...] that follow
" at once.
function! s:Args() abort
  if s:tok.kind ==# '('
    call s:Block()
  endif
  while s:tok.direct && s:tok.kind ==# '['
    call s:Block()
  endwhile
endfunction

" What "let" and "for" bind: a name, "_", or a destructuring (...).
function! s:Pattern() abort
  let l:kind = s:tok.kind
  if l:kind ==# '('
    call s:Block()
  elseif l:kind ==# '_' || has_key(s:keywords, l:kind)
    call s:Eat()
  elseif has_key(s:atom, l:kind)
    call s:Expr(1)
  else
    call s:Expected()
  endif
endfunction

" The { } or [ ] that if, else, while and for run.
function! s:Body() abort
  if s:tok.kind ==# '{' || s:tok.kind ==# '['
    call s:Block()
  else
    call s:Expected()
  endif
endfunction

function! s:If() abort
  call s:Eat()
  call s:Expr(0)
  call s:Body()
  if s:tok.kind ==# 'else'
    call s:Eat()
    if s:tok.kind ==# 'if'
      call s:If()
    else
      call s:Body()
    endif
  endif
endfunction

" import "file.typ" as name: a, b.c as d
function! s:Import() abort
  call s:Eat()
  call s:Expr(0)
  if s:tok.kind ==# 'as'
    call s:Eat()
    call s:Expect('ident')
  endif
  if s:tok.kind !=# ':'
    return
  endif
  call s:Eat()
  if s:tok.kind ==# '('
    call s:Block()
  elseif s:tok.kind ==# '*'
    call s:Eat()
  else
    while !has_key(s:closers, s:tok.kind)
      call s:Eat()
      while s:tok.kind ==# '.'
        call s:Eat()
        call s:Expect('ident')
      endwhile
      if s:tok.kind ==# 'as'
        call s:Eat()
        call s:Expect('ident')
      endif
      if !has_key(s:closers, s:tok.kind)
        call s:Expect(',')
      endif
    endwhile
  endif
endfunction

" ----- a scan

" Make a:frame the innermost frame, as it was where it had a:code.
function! s:Enter(frame, code) abort
  let l:b = a:frame ? get(s:blocks, a:frame, [0, 1, 0, 0]) : [0, 1, 0, 0]
  let s:frame = a:frame
  let s:isgroup = type(l:b[3]) == v:t_list
  let s:nest = s:isgroup ? 0 : max([a:code - 2, 0])
  let s:stack = s:isgroup ? split(get(l:b[3], a:code - 1, ''), '\zs') : []
endfunction

" Scans a:lines from the start of line a:start (from 0), a line that was
" arrived at with a:flag, until s:Arrive() says to stop or the text ends.
" a:safe and a:hi are for s:Arrive(): the flags of the last scan, per line,
" and the last line changed since. a:blocks is s:blocks, added to as blocks
" are found. Time is in seconds, 0 for no limit. After a:budget, or after
" s:span lines, the scan stops at the next line its frame arrives at, to be
" carried on from there.
" After a:cap it stops wherever it is: what it was in the middle of is
" dropped, and it reports having stopped at the line its frame last arrived
" at.
"
" Returns a dictionary:
"   items    the code found: a list of [lnum, col, lnum, end] in order, each
"            within one line, columns in bytes, as prop_add_list() takes them
"   end      the line the scan stopped at, len(a:lines) at the end of the text
"   arrive   [line, flag] for the lines from a:start to there that were
"            arrived at
"   more     1 when it stopped for want of time; endflag is then the flag of
"            the line it stopped at
"   stuck    1 when that was for a:cap
"   outer    -1, or: the frame the scan started in ended and what follows it
"            cannot be entered. Nothing was found; scan again from a line of
"            the frame with this number, which that one is in.
function! s:Scan(lines, start, flag, safe, hi, blocks, budget, cap) abort
  let s:L = a:lines
  let s:nl = len(a:lines)
  let s:out = []
  let s:from = []
  let [s:safe, s:hi, s:blocks, s:budget, s:cap] = [a:safe, a:hi, a:blocks, a:budget, a:cap]
  let [s:arrive, s:at, s:end, s:endflag, s:more, s:ticks] = [[[a:start, a:flag]], [a:start, a:flag], s:nl, 0, 0, 0]
  let s:began = reltime()
  let s:origin = a:start
  call s:Goto(a:start, 0)
  let l:frame = a:flag / 1000
  let l:code = a:flag % 1000
  let l:closed = []
  let l:outer = -1
  call s:Enter(l:frame, l:code)
  if s:isgroup
    " The line starts in the middle of code.
    call s:OpenAt(a:start, 0)
  endif
  " Each level of nesting in the document is some seven calls deep here.
  let l:depth = &maxfuncdepth
  let &maxfuncdepth = max([l:depth, 300])
  try
    while 1
      let [s:live, s:complex, s:stopped] = [l:frame, 0, 0]
      call s:Enter(l:frame, l:code)
      try
        if !empty(l:closed)
          " The frame the scan was in has ended, and the scan is back in the
          " one that opened it: first, what may follow the frame.
          let [l:kind, l:block] = l:closed
          let l:closed = []
          if l:block
            " On the "]" of a content block.
            call s:OpenAt(s:ln, s:col)
            let s:col += 1
          endif
          if l:kind == 1
            call s:Lex(1)
            call s:Postfix(1)
            if s:tok.kind ==# ';' && s:tok.direct
              call s:Eat()
            endif
          endif
          if l:kind != 3
            call s:CloseAt(s:ln, s:col)
          endif
        endif
        if s:isgroup
          call s:Group(l:frame, s:stack)
        else
          call s:Markup(l:frame, s:nest)
        endif
      catch /^prose-into$/
        let [l:frame, l:code] = [s:into, s:intocode]
        continue
      endtry
      if s:stopped || s:ln >= s:nl || l:frame == 0
        break
      endif
      let l:b = get(s:blocks, l:frame, [0, 1, 0, 0])
      if !l:b[2]
        let l:outer = l:b[0]
        break
      endif
      let l:closed = [l:b[2], type(l:b[3]) != v:t_list]
      let [l:frame, l:code] = l:b[0 : 1]
    endwhile
    if s:end == s:nl
      call s:CloseAt(s:nl, 0)
    endif
    return {'items': s:out, 'end': s:end, 'endflag': s:endflag, 'arrive': s:arrive,
          \ 'more': s:more, 'stuck': 0, 'outer': l:outer}
  catch /^prose-abort$/
    let [l:end, l:flag] = s:at
    while !empty(s:out) && s:out[-1][0] > l:end
      call remove(s:out, -1)
    endwhile
    call filter(s:arrive, 'v:val[0] < l:end')
    return {'items': s:out, 'end': l:end, 'endflag': l:flag, 'arrive': s:arrive,
          \ 'more': 1, 'stuck': 1, 'outer': -1}
  catch /^Vim\%((\a\+)\)\=:E132:/
    " Nested deeper than that: the rest stays as the syntax file has it.
    return {'items': s:out, 'end': s:nl, 'endflag': 0, 'arrive': s:arrive,
          \ 'more': 0, 'stuck': 0, 'outer': -1}
  finally
    let &maxfuncdepth = l:depth
    let [s:L, s:safe, s:blocks, s:line] = [[], [], {}, '']
  endtry
endfunction

" For autoload/prose.vim: a go at a buffer's lines. a:span is the most lines
" it may cover.
function! prose#typst#run(lines, start, flag, safe, hi, blocks, budget, cap, span) abort
  let s:span = a:span
  return s:Scan(a:lines, a:start, a:flag, a:safe, a:hi, a:blocks, a:budget, a:cap)
endfunction

" The code in a Typst document given as a list of lines; see "items" above.
function! prose#typst#scan(lines) abort
  return s:Scan(a:lines, 0, 1, [], len(a:lines), {}, 0, 0).items
endfunction

