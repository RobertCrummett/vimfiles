" Name:         custom
" Description:  Vim's bundled "quiet" colorscheme (mostly monochrome) plus
"               three accents used consistently across languages.
" Based on:     colors/quiet.vim by Maxence Weynans (Vim License)
"
" Everything up to the "Custom accents" section is copied from quiet.vim so
" this file does not depend on the system runtime's version of it.

hi clear
let g:colors_name = 'custom'

" Applied after quiet's definitions, just before each of its "finish" exits.
function! s:Accents() abort
  "
  " quiet colours only comments, so three accents carry all the meaning:
  "   customLavendar     functions, calls, definitions (help entries, vim commands)
  "   customLightPurple  special characters, math, options, key notation
  "   customPink         labels, references, links, jumps
  "   customLightBlue    text that completion put or offers to put in the buffer
    hi customLavendar    guifg=#aa9fff guibg=NONE gui=NONE ctermfg=147 ctermbg=NONE cterm=NONE
    hi customLightPurple guifg=#ff9fff guibg=NONE gui=NONE ctermfg=219 ctermbg=NONE cterm=NONE
    hi customPink        guifg=#ff00af guibg=NONE gui=NONE ctermfg=199 ctermbg=NONE cterm=NONE
    hi customLightBlue   guifg=#5fafff guibg=NONE gui=NONE ctermfg=75  ctermbg=NONE cterm=NONE

  " TODO markers stay as quiet as the comments they live in.
  hi! link Todo Comment

  " Standard groups: most languages reach these through their default links.
  hi! link Function    customLavendar
  hi! link Label       customPink
  hi! link SpecialChar customLightPurple

  " Completion: what CTRL-N, CTRL-X and the llm plugin insert or propose
  " (ComplMatchIns is the inserted text, PmenuMatch the matching part of
  " menu entries, LlmGhost the proposed block).
  hi! link ComplMatchIns customLightBlue
  hi! link LlmGhost      customLightBlue
  hi PmenuMatch    guifg=#5fafff guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=75 ctermbg=248 cterm=NONE
  hi PmenuMatchSel guifg=#5fafff guibg=#dadada guisp=NONE gui=bold ctermfg=75 ctermbg=253 cterm=bold

  " Help files
  hi! link helpHyperTextJump  customPink
  hi! link helpHyperTextEntry customLavendar
  hi! link helpOption         customLightPurple

  " Typst
  hi! link typstCodeLabel          customPink
  hi! link typstMarkupLabel        customPink
  hi! link typstMarkupReference    customPink
  hi! link typstHashtagFunction    customLavendar
  hi! link typstHashtagIdentifier  customLavendar
  hi! link typstHashtagFieldAccess customLavendar
  hi! link typstCodeIdentifier     customLavendar
  hi! link typstCodeFunction       customLavendar
  hi! link typstCodeFieldAccess    customLavendar
  hi! link typstMarkupDollar       customLightPurple
  " The $ delimiters themselves (group defined in after/syntax/typst.vim),
  " and math inside code mode and after #, which the bundled syntax leaves
  " plain.
  hi! link typstMathDelim          customLightPurple
  hi! link typstCodeDollar         customLightPurple
  hi! link typstHashtagDollar      customLightPurple
  hi! link typstMathScripts        customLightPurple
  hi! link typstMathNumber         customLightPurple
  hi! link typstMathSymbol         customLightPurple
  hi! link typstMathIdentifier     customLightPurple
  hi! link typstMathFunction       customLightPurple

  " Vimscript: keywords are pink so they stand apart from function names,
  " which stay lavender like functions everywhere else. Ex commands (let,
  " set, augroup, function, for, ...) all link to vimCommand, and the "!"
  " after a command is vimBang. <SID>, <CR>, <silent>, option names and
  " variable scope prefixes (a: b: v: ...) are notation.
  hi! link vimCommand      customPink
  hi! link vimBang         customPink
  hi! link vimFunctionName customLavendar
  hi! link vimUserFunc     customLavendar
  hi! link vimVimVar       customLightPurple
  hi! link vimNotation     customLightPurple
  hi! link vimAutocmdBufferPattern customLightPurple
  hi! link vimMapMod       customLightPurple
  hi! link vimBracket      customLightPurple
  hi! link vimFuncSID      customLightPurple
  hi! link vimOption       customLightPurple
  " Scope prefixes such as a: b: g: l: s: on variables and functions.
  hi! link vimVarScope      customLightPurple
  hi! link vimFunctionScope customLightPurple

  " Rust: macro calls read like calls; lifetimes and escapes are special.
  " Doc comments (//! /// /** */) are comments, not SpecialComment.
  hi! link rustMacro    customLavendar
  hi! link rustEscape   customLightPurple
  hi! link rustLifetime customLightPurple
  hi! link rustCommentLineDoc  Comment
  hi! link rustCommentBlockDoc Comment

  " Python (pythonFunctionCall is defined in after/syntax/python.vim).
  hi! link pythonFunctionCall     customLavendar
  hi! link pythonEscape           customLightPurple
  hi! link pythonFStringDelimiter customLightPurple

  " Shell, batch, PowerShell
  hi! link shSpecial      customLightPurple
  hi! link dosbatchSwitch customLightPurple
  hi! link ps1Function    customLavendar
  " Despite the name, ps1Label matches cmdlet parameters (-Path), not labels.
  hi! link ps1Label       customLightPurple

  " Markdown: headings are entries, links and reference ids are jumps,
  " bare URLs are set apart from the link text.
  hi! link markdownH1            customLavendar
  hi! link markdownH2            customLavendar
  hi! link markdownH3            customLavendar
  hi! link markdownH4            customLavendar
  hi! link markdownH5            customLavendar
  hi! link markdownH6            customLavendar
  hi! link markdownLinkText      customPink
  hi! link markdownId            customPink
  hi! link markdownIdDeclaration customPink
  hi! link markdownUrl           customLightPurple
  hi! link markdownEscape        customLightPurple

  " Lisp
  hi! link lispFunc customLavendar
  hi! link lispKey  customLightPurple

  " Directory listings (plugin/diredit.vim)
  hi! link direditDir     Directory
  hi! link direditNew     customLavendar
  hi! link direditDetails Comment

  " Highlight reports (plugin/synexplore.vim)
  hi! link synexploreTitle   customLavendar
  hi! link synexploreApplies customPink
  hi! link synexploreLabel   customLavendar
  hi! link synexploreYours   customLightPurple
  hi! link synexploreOwner   customLightPurple
  hi! link synexploreItemNum customPink

endfunction

let s:t_Co = has('gui_running') ? 16777216 : str2nr(&t_Co)
let s:tgc = has('termguicolors') && &termguicolors

hi! link Added Normal
hi! link Boolean Constant
hi! link Changed Normal
hi! link Character Constant
hi! link Conditional Statement
hi! link Debug Special
hi! link Define PreProc
hi! link Delimiter Special
hi! link Exception Statement
hi! link Float Constant
hi! link Function Identifier
hi! link Include PreProc
hi! link Keyword Statement
hi! link Label Statement
hi! link Macro PreProc
hi! link MessageWindow Pmenu
hi! link Number Constant
hi! link Operator Statement
hi! link PopupNotification Todo
hi! link PreCondit PreProc
hi! link Removed Normal
hi! link Repeat Statement
hi! link SpecialChar Special
hi! link SpecialComment Special
hi! link StatusLineTerm StatusLine
hi! link StatusLineTermNC StatusLineNC
hi! link StorageClass Type
hi! link String Constant
hi! link Structure Type
hi! link Tag Special
hi! link Terminal Normal
hi! link Typedef Type
hi! link debugBreakpoint ModeMsg
hi! link debugPC CursorLine
hi! link lCursor Cursor

if &background == 'dark'
  let g:terminal_ansi_colors = ['#000000', '#d7005f', '#00af5f', '#d78700', '#0087d7', '#d787d7', '#00afaf', '#dadada', '#707070', '#ff005f', '#00d75f', '#ffaf00', '#5fafff', '#ff87ff', '#00d7d7', '#ffffff']

  hi Normal guifg=#dadada guibg=#000000 guisp=NONE gui=NONE ctermfg=253 ctermbg=16 cterm=NONE term=NONE
  hi ColorColumn guifg=NONE guibg=#1c1c1c guisp=NONE gui=NONE ctermfg=NONE ctermbg=234 cterm=NONE term=reverse
  hi Comment guifg=#707070 guibg=NONE guisp=NONE gui=bold ctermfg=242 ctermbg=NONE cterm=bold term=bold
  hi Conceal guifg=NONE guibg=NONE guisp=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE term=NONE
  hi Constant guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi CurSearch guifg=#ff5fff guibg=#000000 guisp=NONE gui=reverse ctermfg=207 ctermbg=16 cterm=reverse term=reverse
  hi Cursor guifg=NONE guibg=NONE guisp=NONE gui=reverse ctermfg=NONE ctermbg=NONE cterm=reverse term=reverse
  hi CursorColumn guifg=NONE guibg=#303030 guisp=NONE gui=NONE ctermfg=NONE ctermbg=236 cterm=NONE term=NONE
  hi CursorIM guifg=#000000 guibg=#afff00 guisp=NONE gui=NONE ctermfg=16 ctermbg=154 cterm=NONE term=NONE
  hi CursorLine guifg=NONE guibg=#303030 guisp=NONE gui=NONE ctermfg=NONE ctermbg=236 cterm=NONE term=underline
  hi CursorLineNr guifg=#dadada guibg=#303030 guisp=NONE gui=NONE ctermfg=253 ctermbg=236 cterm=NONE term=bold
  hi DiffAdd guifg=#00af00 guibg=#000000 guisp=NONE gui=reverse ctermfg=34 ctermbg=16 cterm=reverse term=reverse
  hi DiffChange guifg=#87afd7 guibg=#000000 guisp=NONE gui=reverse ctermfg=110 ctermbg=16 cterm=reverse term=NONE
  hi DiffDelete guifg=#d75f5f guibg=#000000 guisp=NONE gui=reverse ctermfg=167 ctermbg=16 cterm=reverse term=reverse
  hi DiffText guifg=#d787d7 guibg=#000000 guisp=NONE gui=reverse ctermfg=176 ctermbg=16 cterm=reverse term=reverse
  hi Directory guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi EndOfBuffer guifg=#707070 guibg=NONE guisp=NONE gui=NONE ctermfg=242 ctermbg=NONE cterm=NONE term=NONE
  hi Error guifg=#ff005f guibg=#000000 guisp=NONE gui=bold,reverse ctermfg=197 ctermbg=16 cterm=bold,reverse term=bold,reverse
  hi ErrorMsg guifg=#dadada guibg=#000000 guisp=NONE gui=reverse ctermfg=253 ctermbg=16 cterm=reverse term=bold,reverse
  hi FoldColumn guifg=#707070 guibg=NONE guisp=NONE gui=NONE ctermfg=242 ctermbg=NONE cterm=NONE term=NONE
  hi Folded guifg=#707070 guibg=#000000 guisp=NONE gui=NONE ctermfg=242 ctermbg=16 cterm=NONE term=NONE
  hi Identifier guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi Ignore guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi IncSearch guifg=#ffaf00 guibg=#000000 guisp=NONE gui=reverse ctermfg=214 ctermbg=16 cterm=reverse term=bold,reverse,underline
  hi LineNr guifg=#585858 guibg=NONE guisp=NONE gui=NONE ctermfg=240 ctermbg=NONE cterm=NONE term=NONE
  hi MatchParen guifg=#ff00af guibg=NONE guisp=NONE gui=bold ctermfg=199 ctermbg=NONE cterm=bold term=bold,underline
  hi ModeMsg guifg=#dadada guibg=NONE guisp=NONE gui=bold ctermfg=253 ctermbg=NONE cterm=bold term=bold
  hi MoreMsg guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi NonText guifg=#707070 guibg=NONE guisp=NONE gui=NONE ctermfg=242 ctermbg=NONE cterm=NONE term=NONE
  hi Pmenu guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=reverse
  hi PmenuExtra guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=NONE
  hi PmenuExtraSel guifg=#000000 guibg=#dadada guisp=NONE gui=NONE ctermfg=16 ctermbg=253 cterm=NONE term=NONE
  hi PmenuKind guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=bold ctermfg=16 ctermbg=248 cterm=bold term=bold
  hi PmenuKindSel guifg=#000000 guibg=#dadada guisp=NONE gui=bold ctermfg=16 ctermbg=253 cterm=bold term=bold
  hi PmenuMatch guifg=#d7005f guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=161 ctermbg=248 cterm=NONE term=NONE
  hi PmenuMatchSel guifg=#d7005f guibg=#dadada guisp=NONE gui=bold ctermfg=161 ctermbg=253 cterm=bold term=bold
  hi PmenuSbar guifg=#707070 guibg=#585858 guisp=NONE gui=NONE ctermfg=242 ctermbg=240 cterm=NONE term=reverse
  hi PmenuSel guifg=#000000 guibg=#dadada guisp=NONE gui=NONE ctermfg=16 ctermbg=253 cterm=NONE term=bold
  hi PmenuThumb guifg=#dadada guibg=#dadada guisp=NONE gui=NONE ctermfg=253 ctermbg=253 cterm=NONE term=NONE
  hi PreProc guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi Question guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=standout
  hi QuickFixLine guifg=#ff5fff guibg=#000000 guisp=NONE gui=reverse ctermfg=207 ctermbg=16 cterm=reverse term=NONE
  hi Search guifg=#00afff guibg=#000000 guisp=NONE gui=reverse ctermfg=39 ctermbg=16 cterm=reverse term=reverse
  hi SignColumn guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=reverse
  hi Special guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi SpecialKey guifg=#707070 guibg=NONE guisp=NONE gui=bold ctermfg=242 ctermbg=NONE cterm=bold term=bold
  hi SpellBad guifg=#d7005f guibg=NONE guisp=#d7005f gui=undercurl ctermfg=161 ctermbg=NONE cterm=underline term=underline
  hi SpellCap guifg=#0087d7 guibg=NONE guisp=#0087d7 gui=undercurl ctermfg=32 ctermbg=NONE cterm=underline term=underline
  hi SpellLocal guifg=#d787d7 guibg=NONE guisp=#d787d7 gui=undercurl ctermfg=176 ctermbg=NONE cterm=underline term=underline
  hi SpellRare guifg=#00afaf guibg=NONE guisp=#00afaf gui=undercurl ctermfg=37 ctermbg=NONE cterm=underline term=underline
  hi Statement guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi StatusLine guifg=#000000 guibg=#dadada guisp=NONE gui=bold ctermfg=16 ctermbg=253 cterm=bold term=bold,reverse
  hi StatusLineNC guifg=#707070 guibg=#000000 guisp=NONE gui=reverse ctermfg=242 ctermbg=16 cterm=reverse term=bold,underline
  hi TabLine guifg=#707070 guibg=#000000 guisp=NONE gui=reverse ctermfg=242 ctermbg=16 cterm=reverse term=bold,underline
  hi TabLineFill guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi TabLineSel guifg=#000000 guibg=#dadada guisp=NONE gui=bold ctermfg=16 ctermbg=253 cterm=bold term=bold,reverse
  hi Title guifg=NONE guibg=NONE guisp=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE term=NONE
  hi Todo guifg=#00ffaf guibg=NONE guisp=NONE gui=bold,reverse ctermfg=49 ctermbg=NONE cterm=bold,reverse term=bold,reverse
  hi ToolbarButton guifg=#dadada guibg=#000000 guisp=NONE gui=bold ctermfg=253 ctermbg=16 cterm=bold term=bold,reverse
  hi ToolbarLine guifg=NONE guibg=#000000 guisp=NONE gui=NONE ctermfg=NONE ctermbg=16 cterm=NONE term=reverse
  hi Type guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=NONE
  hi Underlined guifg=#dadada guibg=NONE guisp=NONE gui=underline ctermfg=253 ctermbg=NONE cterm=underline term=underline
  hi VertSplit guifg=#707070 guibg=#000000 guisp=NONE gui=NONE ctermfg=242 ctermbg=16 cterm=NONE term=NONE
  hi Visual guifg=#ffaf00 guibg=#000000 guisp=NONE gui=reverse ctermfg=214 ctermbg=16 cterm=reverse term=reverse
  hi VisualNOS guifg=NONE guibg=#303030 guisp=NONE gui=NONE ctermfg=NONE ctermbg=236 cterm=NONE term=NONE
  hi WarningMsg guifg=#dadada guibg=NONE guisp=NONE gui=NONE ctermfg=253 ctermbg=NONE cterm=NONE term=standout
  hi WildMenu guifg=#00afff guibg=#000000 guisp=NONE gui=bold ctermfg=39 ctermbg=16 cterm=bold term=bold

  if s:tgc || s:t_Co >= 256
    call s:Accents() | finish
  endif

  if s:t_Co >= 16
    hi Normal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi ColorColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Comment ctermfg=darkgrey ctermbg=NONE cterm=bold
    hi Conceal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Constant ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CurSearch ctermfg=magenta ctermbg=black cterm=reverse
    hi Cursor ctermfg=NONE ctermbg=NONE cterm=reverse
    hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorIM ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLine ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLineNr ctermfg=NONE ctermbg=NONE cterm=bold
    hi DiffAdd ctermfg=darkgreen ctermbg=black cterm=reverse
    hi DiffChange ctermfg=darkblue ctermbg=black cterm=reverse
    hi DiffDelete ctermfg=darkred ctermbg=black cterm=reverse
    hi DiffText ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Directory ctermfg=NONE ctermbg=NONE cterm=NONE
    hi EndOfBuffer ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Error ctermfg=darkred ctermbg=black cterm=bold,reverse
    hi ErrorMsg ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi FoldColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Folded ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Identifier ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
    hi IncSearch ctermfg=yellow ctermbg=black cterm=reverse
    hi LineNr ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi MatchParen ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
    hi MoreMsg ctermfg=NONE ctermbg=NONE cterm=NONE
    hi NonText ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Pmenu ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtra ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtraSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuKind ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi PmenuKindSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuMatch ctermfg=NONE ctermbg=darkred cterm=reverse
    hi PmenuMatchSel ctermfg=darkred ctermbg=NONE cterm=bold
    hi PmenuSbar ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi PmenuSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuThumb ctermfg=NONE ctermbg=NONE cterm=NONE
    hi PreProc ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Question ctermfg=NONE ctermbg=NONE cterm=standout
    hi QuickFixLine ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Search ctermfg=cyan ctermbg=black cterm=reverse
    hi SignColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Special ctermfg=NONE ctermbg=NONE cterm=NONE
    hi SpecialKey ctermfg=darkgrey ctermbg=NONE cterm=bold
    hi SpellBad ctermfg=darkred ctermbg=NONE cterm=underline
    hi SpellCap ctermfg=darkblue ctermbg=NONE cterm=underline
    hi SpellLocal ctermfg=darkmagenta ctermbg=NONE cterm=underline
    hi SpellRare ctermfg=darkcyan ctermbg=NONE cterm=underline
    hi Statement ctermfg=NONE ctermbg=NONE cterm=NONE
    hi StatusLine ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi StatusLineNC ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi TabLine ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi TabLineFill ctermfg=NONE ctermbg=NONE cterm=NONE
    hi TabLineSel ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi Title ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Todo ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarButton ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarLine ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Type ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
    hi VertSplit ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Visual ctermfg=darkyellow ctermbg=black cterm=reverse
    hi VisualNOS ctermfg=NONE ctermbg=NONE cterm=NONE
    hi WarningMsg ctermfg=NONE ctermbg=NONE cterm=standout
    hi WildMenu ctermfg=NONE ctermbg=NONE cterm=bold
    call s:Accents() | finish
  endif

  if s:t_Co >= 8
    hi Normal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi ColorColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Comment ctermfg=NONE ctermbg=NONE cterm=bold
    hi Conceal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Constant ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CurSearch ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Cursor ctermfg=NONE ctermbg=NONE cterm=reverse
    hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorIM ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLine ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLineNr ctermfg=NONE ctermbg=NONE cterm=bold
    hi DiffAdd ctermfg=darkgreen ctermbg=black cterm=reverse
    hi DiffChange ctermfg=darkblue ctermbg=black cterm=reverse
    hi DiffDelete ctermfg=darkred ctermbg=black cterm=reverse
    hi DiffText ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Directory ctermfg=NONE ctermbg=NONE cterm=NONE
    hi EndOfBuffer ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Error ctermfg=darkred ctermbg=black cterm=bold,reverse
    hi ErrorMsg ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi FoldColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Folded ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Identifier ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
    hi IncSearch ctermfg=darkyellow ctermbg=black cterm=reverse
    hi LineNr ctermfg=NONE ctermbg=NONE cterm=NONE
    hi MatchParen ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
    hi MoreMsg ctermfg=NONE ctermbg=NONE cterm=NONE
    hi NonText ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Pmenu ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtra ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtraSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuKind ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi PmenuKindSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuMatch ctermfg=NONE ctermbg=darkred cterm=reverse
    hi PmenuMatchSel ctermfg=darkred ctermbg=NONE cterm=bold
    hi PmenuSbar ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuThumb ctermfg=NONE ctermbg=NONE cterm=NONE
    hi PreProc ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Question ctermfg=NONE ctermbg=NONE cterm=standout
    hi QuickFixLine ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Search ctermfg=darkcyan ctermbg=black cterm=reverse
    hi SignColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Special ctermfg=NONE ctermbg=NONE cterm=NONE
    hi SpecialKey ctermfg=NONE ctermbg=NONE cterm=bold
    hi SpellBad ctermfg=darkred ctermbg=NONE cterm=underline
    hi SpellCap ctermfg=darkblue ctermbg=NONE cterm=underline
    hi SpellLocal ctermfg=darkmagenta ctermbg=NONE cterm=underline
    hi SpellRare ctermfg=darkcyan ctermbg=NONE cterm=underline
    hi Statement ctermfg=NONE ctermbg=NONE cterm=NONE
    hi StatusLine ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi StatusLineNC ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi TabLine ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi TabLineFill ctermfg=NONE ctermbg=NONE cterm=NONE
    hi TabLineSel ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi Title ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Todo ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarButton ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarLine ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Type ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
    hi VertSplit ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Visual ctermfg=darkyellow ctermbg=black cterm=reverse
    hi VisualNOS ctermfg=NONE ctermbg=NONE cterm=NONE
    hi WarningMsg ctermfg=NONE ctermbg=NONE cterm=standout
    hi WildMenu ctermfg=NONE ctermbg=NONE cterm=bold
    call s:Accents() | finish
  endif

  if s:t_Co >= 0
    hi CursorLineFold term=underline
    hi CursorLineSign term=underline
    hi Float term=NONE
    hi Function term=NONE
    hi Number term=NONE
    hi StatusLineTerm term=bold,reverse
    hi StatusLineTermNC term=bold,underline
    hi Terminal term=NONE
    call s:Accents() | finish
  endif

  call s:Accents() | finish
endif

if &background == 'light'
  let g:terminal_ansi_colors = ['#000000', '#af0000', '#005f00', '#af5f00', '#005faf', '#870087', '#008787', '#d7d7d7', '#626262', '#d70000', '#008700', '#d78700', '#0087d7', '#af00af', '#00afaf', '#ffffff']

  hi Normal guifg=#000000 guibg=#d7d7d7 guisp=NONE gui=NONE ctermfg=16 ctermbg=188 cterm=NONE term=NONE
  hi ColorColumn guifg=NONE guibg=#e4e4e4 guisp=NONE gui=NONE ctermfg=NONE ctermbg=254 cterm=NONE term=reverse
  hi Comment guifg=#000000 guibg=NONE guisp=NONE gui=bold ctermfg=16 ctermbg=NONE cterm=bold term=bold
  hi Conceal guifg=NONE guibg=NONE guisp=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE term=NONE
  hi Constant guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi CurSearch guifg=#ff5fff guibg=#000000 guisp=NONE gui=reverse ctermfg=207 ctermbg=16 cterm=reverse term=reverse
  hi Cursor guifg=NONE guibg=NONE guisp=NONE gui=reverse ctermfg=NONE ctermbg=NONE cterm=reverse term=reverse
  hi CursorColumn guifg=NONE guibg=#eeeeee guisp=NONE gui=NONE ctermfg=NONE ctermbg=255 cterm=NONE term=NONE
  hi CursorIM guifg=#000000 guibg=#afff00 guisp=NONE gui=NONE ctermfg=16 ctermbg=154 cterm=NONE term=NONE
  hi CursorLine guifg=NONE guibg=#eeeeee guisp=NONE gui=NONE ctermfg=NONE ctermbg=255 cterm=NONE term=underline
  hi CursorLineNr guifg=#000000 guibg=#eeeeee guisp=NONE gui=NONE ctermfg=16 ctermbg=255 cterm=NONE term=bold
  hi DiffAdd guifg=#87d787 guibg=#000000 guisp=NONE gui=reverse ctermfg=114 ctermbg=16 cterm=reverse term=reverse
  hi DiffChange guifg=#afafd7 guibg=#000000 guisp=NONE gui=reverse ctermfg=146 ctermbg=16 cterm=reverse term=NONE
  hi DiffDelete guifg=#d78787 guibg=#000000 guisp=NONE gui=reverse ctermfg=174 ctermbg=16 cterm=reverse term=reverse
  hi DiffText guifg=#d787d7 guibg=#000000 guisp=NONE gui=reverse ctermfg=176 ctermbg=16 cterm=reverse term=reverse
  hi Directory guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi EndOfBuffer guifg=#626262 guibg=NONE guisp=NONE gui=NONE ctermfg=241 ctermbg=NONE cterm=NONE term=NONE
  hi Error guifg=#ff005f guibg=#000000 guisp=NONE gui=bold,reverse ctermfg=197 ctermbg=16 cterm=bold,reverse term=bold,reverse
  hi ErrorMsg guifg=#000000 guibg=#d7d7d7 guisp=NONE gui=reverse ctermfg=16 ctermbg=188 cterm=reverse term=bold,reverse
  hi FoldColumn guifg=#626262 guibg=NONE guisp=NONE gui=NONE ctermfg=241 ctermbg=NONE cterm=NONE term=NONE
  hi Folded guifg=#626262 guibg=#d7d7d7 guisp=NONE gui=NONE ctermfg=241 ctermbg=188 cterm=NONE term=NONE
  hi Identifier guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi Ignore guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi IncSearch guifg=#ffaf00 guibg=#000000 guisp=NONE gui=reverse ctermfg=214 ctermbg=16 cterm=reverse term=bold,reverse,underline
  hi LineNr guifg=#a8a8a8 guibg=NONE guisp=NONE gui=NONE ctermfg=248 ctermbg=NONE cterm=NONE term=NONE
  hi MatchParen guifg=#ff00af guibg=#d7d7d7 guisp=NONE gui=bold ctermfg=199 ctermbg=188 cterm=bold term=bold,underline
  hi ModeMsg guifg=#000000 guibg=NONE guisp=NONE gui=bold ctermfg=16 ctermbg=NONE cterm=bold term=bold
  hi MoreMsg guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi NonText guifg=#626262 guibg=NONE guisp=NONE gui=NONE ctermfg=241 ctermbg=NONE cterm=NONE term=NONE
  hi Pmenu guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=reverse
  hi PmenuExtra guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=NONE
  hi PmenuExtraSel guifg=#d7d7d7 guibg=#000000 guisp=NONE gui=NONE ctermfg=188 ctermbg=16 cterm=NONE term=NONE
  hi PmenuKind guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=bold ctermfg=16 ctermbg=248 cterm=bold term=bold
  hi PmenuKindSel guifg=#d7d7d7 guibg=#000000 guisp=NONE gui=bold ctermfg=188 ctermbg=16 cterm=bold term=bold
  hi PmenuMatch guifg=#d70000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=160 ctermbg=248 cterm=NONE term=NONE
  hi PmenuMatchSel guifg=#d70000 guibg=#000000 guisp=NONE gui=bold ctermfg=160 ctermbg=16 cterm=bold term=bold
  hi PmenuSbar guifg=#000000 guibg=#e4e4e4 guisp=NONE gui=NONE ctermfg=16 ctermbg=254 cterm=NONE term=reverse
  hi PmenuSel guifg=#d7d7d7 guibg=#000000 guisp=NONE gui=NONE ctermfg=188 ctermbg=16 cterm=NONE term=bold
  hi PmenuThumb guifg=#000000 guibg=#000000 guisp=NONE gui=NONE ctermfg=16 ctermbg=16 cterm=NONE term=NONE
  hi PreProc guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi Question guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=standout
  hi QuickFixLine guifg=#ff5fff guibg=#000000 guisp=NONE gui=reverse ctermfg=207 ctermbg=16 cterm=reverse term=NONE
  hi Search guifg=#00afff guibg=#000000 guisp=NONE gui=reverse ctermfg=39 ctermbg=16 cterm=reverse term=reverse
  hi SignColumn guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=reverse
  hi Special guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi SpecialKey guifg=#626262 guibg=NONE guisp=NONE gui=bold ctermfg=241 ctermbg=NONE cterm=bold term=bold
  hi SpellBad guifg=#af0000 guibg=#d7d7d7 guisp=#af0000 gui=undercurl ctermfg=124 ctermbg=188 cterm=underline term=underline
  hi SpellCap guifg=#005faf guibg=#d7d7d7 guisp=#005faf gui=undercurl ctermfg=25 ctermbg=188 cterm=underline term=underline
  hi SpellLocal guifg=#870087 guibg=#d7d7d7 guisp=#870087 gui=undercurl ctermfg=90 ctermbg=188 cterm=underline term=underline
  hi SpellRare guifg=#008787 guibg=#d7d7d7 guisp=#008787 gui=undercurl ctermfg=30 ctermbg=188 cterm=underline term=underline
  hi Statement guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi StatusLine guifg=#eeeeee guibg=#000000 guisp=NONE gui=bold ctermfg=255 ctermbg=16 cterm=bold term=bold,reverse
  hi StatusLineNC guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=bold,underline
  hi TabLine guifg=#000000 guibg=#a8a8a8 guisp=NONE gui=NONE ctermfg=16 ctermbg=248 cterm=NONE term=bold,underline
  hi TabLineFill guifg=#000000 guibg=#d7d7d7 guisp=NONE gui=NONE ctermfg=16 ctermbg=188 cterm=NONE term=NONE
  hi TabLineSel guifg=#eeeeee guibg=#000000 guisp=NONE gui=bold ctermfg=255 ctermbg=16 cterm=bold term=bold,reverse
  hi Title guifg=NONE guibg=NONE guisp=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE term=NONE
  hi Todo guifg=#00ffaf guibg=#000000 guisp=NONE gui=bold,reverse ctermfg=49 ctermbg=16 cterm=bold,reverse term=bold,reverse
  hi ToolbarButton guifg=#000000 guibg=#d7d7d7 guisp=NONE gui=bold ctermfg=16 ctermbg=188 cterm=bold term=bold,reverse
  hi ToolbarLine guifg=NONE guibg=#d7d7d7 guisp=NONE gui=NONE ctermfg=NONE ctermbg=188 cterm=NONE term=reverse
  hi Type guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=NONE
  hi Underlined guifg=#000000 guibg=NONE guisp=NONE gui=underline ctermfg=16 ctermbg=NONE cterm=underline term=underline
  hi VertSplit guifg=#626262 guibg=#d7d7d7 guisp=NONE gui=NONE ctermfg=241 ctermbg=188 cterm=NONE term=NONE
  hi Visual guifg=#ffaf00 guibg=#000000 guisp=NONE gui=reverse ctermfg=214 ctermbg=16 cterm=reverse term=reverse
  hi VisualNOS guifg=NONE guibg=#eeeeee guisp=NONE gui=NONE ctermfg=NONE ctermbg=255 cterm=NONE term=NONE
  hi WarningMsg guifg=#000000 guibg=NONE guisp=NONE gui=NONE ctermfg=16 ctermbg=NONE cterm=NONE term=standout
  hi WildMenu guifg=#000000 guibg=#eeeeee guisp=NONE gui=bold ctermfg=16 ctermbg=255 cterm=bold term=bold

  if s:tgc || s:t_Co >= 256
    call s:Accents() | finish
  endif

  if s:t_Co >= 16
    hi Normal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi ColorColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Comment ctermfg=NONE ctermbg=NONE cterm=bold
    hi Conceal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Constant ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CurSearch ctermfg=magenta ctermbg=black cterm=reverse
    hi Cursor ctermfg=NONE ctermbg=NONE cterm=reverse
    hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorIM ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLine ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLineNr ctermfg=NONE ctermbg=NONE cterm=bold
    hi DiffAdd ctermfg=darkgreen ctermbg=black cterm=reverse
    hi DiffChange ctermfg=darkblue ctermbg=black cterm=reverse
    hi DiffDelete ctermfg=darkred ctermbg=black cterm=reverse
    hi DiffText ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Directory ctermfg=NONE ctermbg=NONE cterm=NONE
    hi EndOfBuffer ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Error ctermfg=darkred ctermbg=black cterm=bold,reverse
    hi ErrorMsg ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi FoldColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Folded ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Identifier ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
    hi IncSearch ctermfg=yellow ctermbg=black cterm=reverse
    hi LineNr ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi MatchParen ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
    hi MoreMsg ctermfg=NONE ctermbg=NONE cterm=NONE
    hi NonText ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Pmenu ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtra ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtraSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuKind ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi PmenuKindSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuMatch ctermfg=NONE ctermbg=darkred cterm=reverse
    hi PmenuMatchSel ctermfg=darkred ctermbg=NONE cterm=bold
    hi PmenuSbar ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi PmenuSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuThumb ctermfg=NONE ctermbg=NONE cterm=NONE
    hi PreProc ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Question ctermfg=NONE ctermbg=NONE cterm=standout
    hi QuickFixLine ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Search ctermfg=cyan ctermbg=black cterm=reverse
    hi SignColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Special ctermfg=NONE ctermbg=NONE cterm=NONE
    hi SpecialKey ctermfg=darkgrey ctermbg=NONE cterm=bold
    hi SpellBad ctermfg=darkred ctermbg=NONE cterm=underline
    hi SpellCap ctermfg=darkblue ctermbg=NONE cterm=underline
    hi SpellLocal ctermfg=darkmagenta ctermbg=NONE cterm=underline
    hi SpellRare ctermfg=darkcyan ctermbg=NONE cterm=underline
    hi Statement ctermfg=NONE ctermbg=NONE cterm=NONE
    hi StatusLine ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi StatusLineNC ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi TabLine ctermfg=darkgrey ctermbg=NONE cterm=reverse
    hi TabLineFill ctermfg=NONE ctermbg=NONE cterm=NONE
    hi TabLineSel ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi Title ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Todo ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarButton ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarLine ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Type ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
    hi VertSplit ctermfg=darkgrey ctermbg=NONE cterm=NONE
    hi Visual ctermfg=darkyellow ctermbg=black cterm=reverse
    hi VisualNOS ctermfg=NONE ctermbg=NONE cterm=NONE
    hi WarningMsg ctermfg=NONE ctermbg=NONE cterm=standout
    hi WildMenu ctermfg=NONE ctermbg=NONE cterm=bold
    call s:Accents() | finish
  endif

  if s:t_Co >= 8
    hi Normal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi ColorColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Comment ctermfg=NONE ctermbg=NONE cterm=bold
    hi Conceal ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Constant ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CurSearch ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Cursor ctermfg=NONE ctermbg=NONE cterm=reverse
    hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorIM ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLine ctermfg=NONE ctermbg=NONE cterm=NONE
    hi CursorLineNr ctermfg=NONE ctermbg=NONE cterm=bold
    hi DiffAdd ctermfg=darkgreen ctermbg=black cterm=reverse
    hi DiffChange ctermfg=darkblue ctermbg=black cterm=reverse
    hi DiffDelete ctermfg=darkred ctermbg=black cterm=reverse
    hi DiffText ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Directory ctermfg=NONE ctermbg=NONE cterm=NONE
    hi EndOfBuffer ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Error ctermfg=darkred ctermbg=black cterm=bold,reverse
    hi ErrorMsg ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi FoldColumn ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Folded ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Identifier ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
    hi IncSearch ctermfg=darkyellow ctermbg=black cterm=reverse
    hi LineNr ctermfg=NONE ctermbg=NONE cterm=NONE
    hi MatchParen ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
    hi MoreMsg ctermfg=NONE ctermbg=NONE cterm=NONE
    hi NonText ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Pmenu ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtra ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuExtraSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuKind ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi PmenuKindSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuMatch ctermfg=NONE ctermbg=darkred cterm=reverse
    hi PmenuMatchSel ctermfg=darkred ctermbg=NONE cterm=bold
    hi PmenuSbar ctermfg=NONE ctermbg=NONE cterm=reverse
    hi PmenuSel ctermfg=NONE ctermbg=NONE cterm=bold
    hi PmenuThumb ctermfg=NONE ctermbg=NONE cterm=NONE
    hi PreProc ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Question ctermfg=NONE ctermbg=NONE cterm=standout
    hi QuickFixLine ctermfg=darkmagenta ctermbg=black cterm=reverse
    hi Search ctermfg=darkcyan ctermbg=black cterm=reverse
    hi SignColumn ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Special ctermfg=NONE ctermbg=NONE cterm=NONE
    hi SpecialKey ctermfg=NONE ctermbg=NONE cterm=bold
    hi SpellBad ctermfg=darkred ctermbg=NONE cterm=underline
    hi SpellCap ctermfg=darkblue ctermbg=NONE cterm=underline
    hi SpellLocal ctermfg=darkmagenta ctermbg=NONE cterm=underline
    hi SpellRare ctermfg=darkcyan ctermbg=NONE cterm=underline
    hi Statement ctermfg=NONE ctermbg=NONE cterm=NONE
    hi StatusLine ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi StatusLineNC ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi TabLine ctermfg=NONE ctermbg=NONE cterm=bold,underline
    hi TabLineFill ctermfg=NONE ctermbg=NONE cterm=NONE
    hi TabLineSel ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi Title ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Todo ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarButton ctermfg=NONE ctermbg=NONE cterm=bold,reverse
    hi ToolbarLine ctermfg=NONE ctermbg=NONE cterm=reverse
    hi Type ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
    hi VertSplit ctermfg=NONE ctermbg=NONE cterm=NONE
    hi Visual ctermfg=darkyellow ctermbg=black cterm=reverse
    hi VisualNOS ctermfg=NONE ctermbg=NONE cterm=NONE
    hi WarningMsg ctermfg=NONE ctermbg=NONE cterm=standout
    hi WildMenu ctermfg=NONE ctermbg=NONE cterm=bold
    call s:Accents() | finish
  endif

  if s:t_Co >= 0
    hi CursorLineFold term=underline
    hi CursorLineSign term=underline
    hi Float term=NONE
    hi Function term=NONE
    hi Number term=NONE
    hi StatusLineTerm term=bold,reverse
    hi StatusLineTermNC term=bold,underline
    hi Terminal term=NONE
    call s:Accents() | finish
  endif

endif



call s:Accents()
" vim: et ts=8 sw=2 sw=2 sts=2
