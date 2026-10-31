" The Lean goal window (autoload/lean/goal.vim). Only the shape of it is
" marked: the text of a goal or a message is not parsed as Lean, since one
" stray quote in a message would colour the rest of the window.
if exists('b:current_syntax')
  finish
endif
scriptencoding utf-8

syn match leangoalHeading "^\%(Tactic state\%( (\d\+ goals)\)\?\|Expected type\|Messages\|No goals\|No goal here\)$"
syn match leangoalBusy "^Lean is working …$"
syn match leangoalCase "^case\s.*$"
syn match leangoalTurnstile "^⊢"
syn match leangoalError "^\d\+:\d\+ error$"
syn match leangoalWarning "^\d\+:\d\+ \%(warning\|info\|hint\)$"

hi def link leangoalHeading   Title
hi def link leangoalBusy      Comment
hi def link leangoalCase      Label
hi def link leangoalTurnstile SpecialChar
hi def link leangoalError     ErrorMsg
hi def link leangoalWarning   WarningMsg

let b:current_syntax = 'leangoal'
