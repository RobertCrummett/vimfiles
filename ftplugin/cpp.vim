if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal cindent
setlocal cinoptions+=:0,b1,l1

setlocal shiftwidth=4
setlocal softtabstop=-1
