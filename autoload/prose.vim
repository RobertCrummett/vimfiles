" prose: while 'spell' is on in a window, draw everything that is not prose
" in grey, so that only the text being proofread stands out. For Typst and
" LaTeX. See :help prose.
"
" This file marks buffers. Which parts of a document are not prose is told
" by a scanner for its language, autoload/prose/{language}.vim, through
"
"   prose#{language}#run(lines, start, flag, safe, hi, blocks, budget, cap, span)
"
" which scans a:lines from the start of line a:start (from 0) and returns a
" dictionary with
"   items    the code found: a list of [lnum, col, lnum, end] in order, each
"            within one line, columns in bytes, as prop_add_list() takes them
"   end      the line the scan stopped at, len(a:lines) at the end of the text
"   arrive   [line, flag] for the lines from a:start to there at which a
"            scan can start: with that flag, it finds what the whole scan
"            would. Flag 1 is for line 0; the others are the scanner's own.
"   more     1 when it stopped for want of time; endflag is then the flag of
"            the line it stopped at
"   stuck    1 when that was for a:cap
"   outer    -1, or the number of the frame to scan again from: see s:Run()
" a:flag is the flag of line a:start. a:safe and a:hi let the scan stop
" early: the flags of the last scan, per line, and the last line changed
" since. a:blocks is the scanner's to keep what it must know about its
" frames in, by number; a flag is 1000 times a frame's number plus what the
" scanner likes, and the first item kept for a frame is the number of the
" frame it is in (which is all this file reads of it). a:budget and a:cap
" are in seconds, 0 for no limit: after a:budget, or after a:span lines,
" the scan stops at the next line it can start from again; after a:cap it
" stops wherever it is, and reports the last such line.

" filetype -> language
let s:languages = {'typst': 'typst', 'tex': 'tex'}

" ----------------------------------------------------------------- buffers
"
" The code is marked with text properties, which override the syntax colours
" and move with the text as it is edited. What an edit may have changed is
" scanned again from a timer, and only as far as needed: from the last line
" before the edit that a scan can start at, until the scan arrives, in the
" same place, at a line below the edit that the previous scan arrived at
" too. For a change in a paragraph that is the line itself, also inside a
" block or an argument of any length.
"
" s:bufs[bufnr] is the state of a buffer that has been marked:
"   language  the scanner's name
"   shown     1 while the marks are to be seen. With 'spell' off they stay
"             on the text, without a colour, and are still told of changes:
"             turning it on again then costs a scan of what changed, not of
"             the file.
"   safe      per line (from 0), the flag it was arrived at with, or 0
"   blocks    the scanner's frames, for the flags in safe
"   dirty     1 when lines lo to hi (from 0) have changed since they were
"             scanned; hi is below lo after a deletion
"   lines     the text, kept from one go to the next while it has not changed
"   held      marks that were found and are not on the text yet, for lines
"             from to upto - 1 (from 0); see s:Wait()
"   timer     the pending timer, or 0
"   listener  from listener_add()
"   mender    from listener_add() too, for s:Mend(); 0 in a Vim without it
"   fresh     set by the listener: s:Run() uses it to see whether a change
"             was still waiting to be told of
"   cost      how long the last go took, in milliseconds
"
" Nothing here may make typing wait. A scan runs from a timer, so not while
" keys are being handled, and in goes of s:slice: between two of them Vim
" takes the keys typed meanwhile. Only what a scanner cannot stop in the
" middle of, such as a long statement in Typst, cannot be cut up. A go is
" therefore given up after twice what the last one took (and never less than
" s:least), and tried again with twice as long, but only once the buffer has
" been left alone for several times that: s:Later() waits six times the
" cost of the last go, starting over at every change when that is long.

let s:type = 'proseCode'
let s:bufs = {}
let s:slice = 0.008
let s:least = 0.015
" The most lines one go may cover. Vim keeps one range of changed lines per
" buffer between two redraws, and when it draws a window below that range it
" parses the syntax of all of it again: measured at the end of a 14000 line
" file, marks changed at line 3900 cost 1 ms to redraw, a character typed at
" line 13780 0.3 ms, and both in one redraw 350 ms. So a go stays within
" this many lines, and s:Run() leaves the marks alone while text that was
" typed is still to be drawn. (It cannot have it drawn itself: ":redraw"
" from a timer loses typed keys in the Windows console, as getchar(1) does.)
let s:span = 250
" Above this cost, in milliseconds, wait for a pause in the typing.
let s:heavy = 12.0

function! s:Reset(buf) abort
  let l:st = s:bufs[a:buf]
  let l:n = getbufinfo(a:buf)[0].linecount
  let l:st.safe = [1] + repeat([0], l:n - 1)
  let l:st.blocks = {}
  let l:st.keep = 4000
  let [l:st.dirty, l:st.lo, l:st.hi] = [1, 0, l:n - 1]
  let [l:st.held, l:st.from, l:st.upto] = [[], 0, 0]
  call prop_remove({'type': s:type, 'bufnr': a:buf, 'all': v:true})
endfunction

" Whether the marks for the lines before a:upto (from 0) can wait: when
" every window on the buffer starts below them. Marks changed above a window
" make Vim work out the syntax at the top of that window again, even though
" nothing in it changes. With "syntax sync fromstart", as Typst has, that
" is the lines whose marks changed, parsed once more: little for one go,
" and for a whole file at once as long as parsing the file. With the
" "minlines" and "maxlines" that the bundled LaTeX syntax has, it is a
" search for a place to start from, 50 ms whatever changed, and that after
" every go of 8 ms. So in a buffer whose syntax file says so with
" b:prose_hold (after/syntax/tex.vim, for a long file), what a scan finds
" above all windows is kept until the scan comes to the first of them or
" ends, and put on the text in one go.
function! s:Wait(buf, upto) abort
  if !getbufvar(a:buf, 'prose_hold', 0)
    return 0
  endif
  let l:wins = win_findbuf(a:buf)
  for l:win in l:wins
    if getwininfo(l:win)[0].topline <= a:upto
      return 0
    endif
  endfor
  return !empty(l:wins)
endfunction

" Put the marks that were held back on the text.
function! s:Commit(buf, st) abort
  if a:st.upto > a:st.from
    call prop_remove({'type': s:type, 'bufnr': a:buf, 'all': v:true}, a:st.from + 1, a:st.upto)
    if !empty(a:st.held)
      call prop_add_list({'type': s:type, 'bufnr': a:buf}, a:st.held)
    endif
  endif
  let [a:st.held, a:st.from, a:st.upto] = [[], 0, 0]
endfunction

function! s:Schedule(buf, ms) abort
  let l:st = s:bufs[a:buf]
  " Marks that are not seen are scanned again when they are next to be seen.
  " Without s:Mend() they cannot be left alone that long.
  if !l:st.timer && (l:st.shown || get(g:, 'prose_eager', 0) || !l:st.mender)
    let l:st.timer = timer_start(a:ms, function('s:Run', [a:buf]))
  endif
endfunction

" Scan a while after the last change: at once when that is cheap, and when
" it is not, only after the typing has paused for six times what it costs.
function! s:Later(buf) abort
  let l:st = s:bufs[a:buf]
  if l:st.cost > s:heavy
    call timer_stop(l:st.timer)
    let l:st.timer = 0
  endif
  call s:Schedule(a:buf, float2nr(min([max([30.0, 6 * l:st.cost]), 3000.0])))
endfunction

" Called for every change as it is made. A line that is split inside a mark,
" by Enter or by ":s/x/\r/", leaves the mark in two parts that Vim holds
" for one property over two lines. Vim 9.2 does not keep such a pair in
" order: with an empty line put between the two and the lower one then
" joined to it (Enter, Enter, Backspace), it reports internal errors (E340,
" E685, E967) and the rest of the line is gone until an undo. So the parts
" are made properties of their own at once: before the next key, also when
" keys come in a run, and also while the marks are not being scanned.
function! s:Mend(buf, start, end, added, changes) abort
  if a:added <= 0
    return
  endif
  try
    let l:last = min([a:end + a:added - 1, a:start + 200, getbufinfo(a:buf)[0].linecount])
    let l:how = {'bufnr': a:buf, 'types': [s:type]}
    let l:split = {}
    for l:p in prop_list(a:start, extend({'end_lnum': l:last}, l:how))
      if !l:p.start || !l:p.end
        let l:split[l:p.lnum] = 1
      endif
    endfor
    for l:key in keys(l:split)
      let l:lnum = str2nr(l:key)
      let l:parts = prop_list(l:lnum, l:how)
      call prop_remove({'type': s:type, 'bufnr': a:buf, 'all': v:true}, l:lnum)
      for l:p in l:parts
        if l:p.length > 0
          call prop_add(l:lnum, l:p.col, {'type': s:type, 'bufnr': a:buf, 'length': l:p.length})
        endif
      endfor
    endfor
  catch
  endtry
endfunction

" The listener. a:changes are the changes one by one, in the order they were
" made, each with the line numbers of its own time. (a:start, a:end and
" a:added sum them up, but a:end is the largest end of any of them, which
" for a change below one that added or removed lines is a line number of a
" later time than a:start: taken as one block, an undo that deleted lines
" in one place and changed a line further down came out short.)
function! s:Changed(buf, start, end, added, changes) abort
  let l:st = get(s:bufs, a:buf, {})
  if empty(l:st)
    return
  endif
  let l:st.fresh = 1
  for l:c in a:changes
    if !s:Change(l:st, l:c.lnum, l:c.end, l:c.added)
      " Not what we have been told so far: start over.
      call s:Reset(a:buf)
      call s:Schedule(a:buf, 30)
      return
    endif
  endfor
  call s:Later(a:buf)
endfunction

" Lines a:start to a:end - 1 (from 1) were replaced by a:added more, or
" fewer, lines. Keeps "safe" in step with the buffer and widens the dirty
" range. A line is arrived at the same way however its own text changes, so
" the first changed line keeps its flag; the lines after it are unknown.
" Returns 0 when the change does not fit the buffer as it was known.
function! s:Change(st, start, end, added) abort
  let l:st = a:st
  let l:first = a:start - 1
  let l:old = a:end - a:start
  let l:new = l:old + a:added
  if l:first > len(l:st.safe) || l:first + l:old > len(l:st.safe) || l:new < 0
    return 0
  endif
  if l:st.upto > l:st.from && l:first < l:st.upto
    " The marks that are held back are for the text as it was: those lines
    " are to be scanned again.
    if l:st.dirty
      let [l:st.lo, l:st.hi] = [min([l:st.lo, l:st.from]), max([l:st.hi, l:st.upto - 1])]
    else
      let [l:st.dirty, l:st.lo, l:st.hi] = [1, l:st.from, l:st.upto - 1]
    endif
    let [l:st.held, l:st.from, l:st.upto] = [[], 0, 0]
  endif
  let l:keep = get(l:st.safe, l:first, 0)
  if l:old > 0
    call remove(l:st.safe, l:first, l:first + l:old - 1)
  endif
  if l:new > 0
    call extend(l:st.safe, [l:keep] + repeat([0], l:new - 1), l:first)
  elseif l:first < len(l:st.safe)
    " Only deleted: the line that moved up is now reached as the first of
    " the deleted lines was.
    let l:st.safe[l:first] = l:keep
  endif
  let l:last = l:first + max([l:new, 1]) - 1
  if l:st.dirty
    if l:st.lo >= l:first + l:old
      let l:st.lo += a:added
    endif
    if l:st.hi >= l:first + l:old
      let l:st.hi += a:added
    endif
    let l:st.lo = min([l:st.lo, l:first])
    let l:st.hi = max([l:st.hi, l:last])
  else
    let [l:st.dirty, l:st.lo, l:st.hi] = [1, l:first, l:last]
  endif
  return 1
endfunction

" Forget the frames that no flag refers to any more, nor any frame one of
" those is in.
function! s:Prune(st) abort
  let l:used = {}
  for l:flag in a:st.safe
    let l:id = l:flag / 1000
    while l:id && !has_key(l:used, l:id) && has_key(a:st.blocks, l:id)
      let l:used[l:id] = a:st.blocks[l:id]
      let l:id = l:used[l:id][0]
    endwhile
  endfor
  let a:st.blocks = l:used
  let a:st.keep = 2 * len(l:used) + 4000
endfunction

function! s:Run(buf, timer) abort
  let l:st = get(s:bufs, a:buf, {})
  if empty(l:st)
    return
  endif
  let l:st.timer = 0
  if !bufloaded(a:buf)
    call s:Drop(a:buf)
    return
  endif
  let l:st.fresh = 0
  call listener_flush(a:buf)
  if !l:st.dirty
    return
  elseif a:timer && l:st.fresh
    " Text has changed that Vim has not drawn yet, or it would have told of
    " the change before. Marks changed now would be drawn with it; see s:span.
    call s:Schedule(a:buf, 40)
    return
  endif
  let l:began = reltime()
  let l:tick = getbufvar(a:buf, 'changedtick')
  if l:st.tick != l:tick
    let l:st.lines = getbufline(a:buf, 1, '$')
    let l:st.tick = l:tick
  endif
  let l:n = len(l:st.lines)
  if len(l:st.safe) != l:n
    call s:Reset(a:buf)
  endif
  let l:st.safe[0] = 1
  let l:start = min([l:st.lo, l:n - 1])
  while !l:st.safe[l:start] || (l:st.safe[l:start] >= 1000 && !has_key(l:st.blocks, l:st.safe[l:start] / 1000))
    let l:start -= 1
  endwhile
  " From prose#flush() (no timer) the scan takes as long as it takes.
  let l:cap = a:timer == 0 ? 0 : max([s:least, 0.002 * l:st.cost])
  while 1
    let l:r = call(l:st.run, [l:st.lines, l:start, l:st.safe[l:start], l:st.safe, l:st.hi, l:st.blocks, s:slice, l:cap, s:span])
    if l:r.outer < 0
      break
    endif
    " The frame the scan started in ended before the scan met the old one,
    " and the scanner cannot tell what follows it. Start again from the
    " nearest line above that the frame this one is in arrived at.
    let l:start -= 1
    while l:start > 0 && (!l:st.safe[l:start] || l:st.safe[l:start] / 1000 != l:r.outer)
      let l:start -= 1
    endwhile
  endwhile
  if l:r.end > l:start
    if l:st.upto > l:st.from && l:start != l:st.upto
      " Not where the last go left off.
      call s:Commit(a:buf, l:st)
    endif
    if l:st.upto == l:st.from
      let l:st.from = l:start
    endif
    call extend(l:st.held, l:r.items)
    let l:st.upto = l:r.end
    let l:st.safe[l:start : l:r.end - 1] = repeat([0], l:r.end - l:start)
    for [l:l, l:flag] in l:r.arrive
      let l:st.safe[l:l] = l:flag
    endfor
  endif
  " The cost is that of finding the marks. Putting on the text all that was
  " held back takes longer, once, and says nothing about the next go.
  let l:st.cost = reltimefloat(reltime(l:began)) * 1000
  if a:timer == 0 || !l:r.more || !s:Wait(a:buf, l:st.upto)
    call s:Commit(a:buf, l:st)
  endif
  if !l:r.more
    let l:st.dirty = 0
    let [l:st.lines, l:st.tick] = [[], -1]
    if len(l:st.blocks) > l:st.keep
      call s:Prune(l:st)
    endif
    return
  endif
  " Not done: carry on from the line it stopped at. That line counts as
  " changed, or a change above it, which moves lo up and leaves hi, would
  " have the next go stop there for finding it as it was.
  let l:st.safe[l:r.end] = l:r.endflag
  let l:st.lo = l:r.end
  let l:st.hi = max([l:st.hi, l:r.end])
  if l:r.stuck
    " What starts there needs longer than it was given. Remember that as the
    " cost, which doubles the time it gets and lengthens the wait before it.
    let l:st.cost = 1000 * l:cap
    call s:Later(a:buf)
  else
    call s:Schedule(a:buf, 1)
  endif
endfunction

" Whether the marks of a buffer are to be seen. The type of the property is
" the buffer's own, so this is one change, whatever the number of marks: a
" highlight that replaces the syntax colour, or one that sets nothing and
" is added to it.
function! s:Show(buf, on) abort
  let s:bufs[a:buf].shown = a:on
  if !hlexists('proseOff')
    highlight proseOff NONE
  endif
  let l:how = a:on ? {'highlight': 'proseCode', 'combine': v:false} : {'highlight': 'proseOff', 'combine': v:true}
  call prop_type_change(s:type, extend(l:how, {'bufnr': a:buf}))
  if s:bufs[a:buf].dirty
    call s:Schedule(a:buf, 0)
  endif
endfunction

function! s:Start(buf, language, shown) abort
  if empty(prop_type_get(s:type, {'bufnr': a:buf}))
    call prop_type_add(s:type, {'bufnr': a:buf, 'highlight': 'proseCode', 'combine': v:false})
  endif
  let s:bufs[a:buf] = {'language': a:language, 'run': function('prose#' . a:language . '#run'),
        \ 'timer': 0, 'cost': 0.0, 'shown': 0, 'lines': [], 'tick': -1, 'fresh': 0,
        \ 'held': [], 'from': 0, 'upto': 0}
  let s:bufs[a:buf].listener = listener_add(function('s:Changed'), a:buf)
  try
    let s:bufs[a:buf].mender = listener_add(function('s:Mend'), a:buf, v:true)
  catch
    let s:bufs[a:buf].mender = 0
  endtry
  " For the plugin's autocommands: this buffer is ours to unmark, whatever
  " becomes of its filetype.
  call setbufvar(a:buf, 'prose', 1)
  call s:Reset(a:buf)
  augroup prose_buffers
    execute 'autocmd! * <buffer=' . a:buf . '>'
    " Reloaded (:edit!, or changed on disk): the text is new, the listener
    " was told nothing.
    execute 'autocmd BufReadPost <buffer=' . a:buf . '> call s:Reload(' . a:buf . ')'
    execute 'autocmd BufUnload <buffer=' . a:buf . '> call s:Drop(' . a:buf . ')'
  augroup END
  call s:Show(a:buf, a:shown)
endfunction

function! s:Reload(buf) abort
  if has_key(s:bufs, a:buf)
    call s:Reset(a:buf)
    call s:Schedule(a:buf, 0)
  endif
endfunction

" Stop following a buffer; its marks, if it still has any, stay.
function! s:Drop(buf) abort
  let l:st = remove(s:bufs, a:buf)
  call timer_stop(l:st.timer)
  call listener_remove(l:st.listener)
  if l:st.mender
    call listener_remove(l:st.mender)
  endif
  call setbufvar(a:buf, 'prose', 0)
  augroup prose_buffers
    execute 'autocmd! * <buffer=' . a:buf . '>'
  augroup END
endfunction

function! s:Stop(buf) abort
  call s:Drop(a:buf)
  call prop_remove({'type': s:type, 'bufnr': a:buf, 'all': v:true})
  call prop_type_delete(s:type, {'bufnr': a:buf})
endfunction

" The language of the current buffer, '' when it is not one of ours.
function! prose#language() abort
  return get(g:, 'prose', 1) ? get(s:languages, &filetype, '') : ''
endfunction

" Show or hide the marks of the current buffer to suit the current window:
" shown while the window has 'spell' set and the buffer is in a language
" with a scanner. 'spell' belongs to the window and the marks to the buffer,
" so with two windows on one buffer the one that was entered last decides.
function! prose#sync() abort
  let l:buf = bufnr()
  let l:language = prose#language()
  if has_key(s:bufs, l:buf) && s:bufs[l:buf].language !=# l:language
    call s:Stop(l:buf)
  endif
  if empty(l:language)
    return
  elseif !has_key(s:bufs, l:buf)
    " With g:prose_eager the marks are made, unseen, as soon as there is a
    " buffer for them, so that they are there when 'spell' is first set.
    if &l:spell || get(g:, 'prose_eager', 0)
      call s:Start(l:buf, l:language, &l:spell)
    endif
  elseif s:bufs[l:buf].shown != &l:spell
    call s:Show(l:buf, &l:spell)
  endif
endfunction

" For tests: the state of a buffer that has been marked, {} for any other.
function! prose#status(...) abort
  let l:st = get(s:bufs, a:0 ? a:1 : bufnr(), {})
  return empty(l:st) ? {} : {'language': l:st.language, 'shown': l:st.shown, 'dirty': l:st.dirty,
        \ 'cost': l:st.cost, 'safe': copy(l:st.safe), 'blocks': len(l:st.blocks), 'held': l:st.upto - l:st.from}
endfunction

" Bring the marks of a buffer up to date now, without waiting for the timer.
function! prose#flush(...) abort
  let l:buf = a:0 ? a:1 : bufnr()
  call listener_flush(l:buf)
  while has_key(s:bufs, l:buf) && s:bufs[l:buf].dirty
    call timer_stop(s:bufs[l:buf].timer)
    call s:Run(l:buf, 0)
  endwhile
endfunction
