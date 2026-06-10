if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal smartindent
setlocal shiftwidth=2
setlocal softtabstop=2

setlocal commentstring=\"%s
