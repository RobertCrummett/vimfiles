" Layered on $VIMRUNTIME/syntax/lua.vim. Coloured by colors/custom.vim.

" Calls, as Lua writes them: f(x), f"s", f's', f[[s]] and f{t}, the last
" name of a.b.c(x) and obj:m(x), and so the name a function statement
" defines too. The bundled rules match no call but those of the library.
" if, while and function start regions there, not keywords, and a match
" defined later wins over a region at the same place: the keywords are kept
" out by name.
syn match luaFunctionCall
  \ /\<\%(\%(and\|break\|do\|else\|elseif\|end\|false\|for\|function\|goto\|if\|in\|local\|nil\|not\|or\|repeat\|return\|then\|true\|until\|while\)\>\)\@!\h\w*\ze\s*\%([("'{]\|\[=*\[\)/
  \ display

" The library names that are values, not functions: the bundled rules list
" them with the functions. A later keyword or match wins over the earlier.
syn keyword luaBuiltinValue self _G _ENV _VERSION
syn match luaBuiltinValue
  \ /\<\%(math\.\%(pi\|huge\|maxinteger\|mininteger\)\|io\.std\%(in\|out\|err\)\|package\.\%(path\|cpath\|config\|loaded\|preload\|searchers\|loaders\)\|utf8\.charpattern\)\>/

" goto and the label it names, which the bundled rules leave a plain
" statement and a plain name; its ::label:: is already a Label.
syn keyword luaGoto goto nextgroup=luaGotoLabel skipwhite
syn match luaGotoLabel /\h\w*/ contained

" The attributes of Lua 5.4: local x <const>, local f <close>.
syn match luaAttribute /<\s*\%(const\|close\)\s*>/

hi def link luaFunctionCall luaFunc
hi def link luaBuiltinValue Identifier
hi def link luaGoto         luaLabel
hi def link luaGotoLabel    luaLabel
hi def link luaAttribute    PreProc
