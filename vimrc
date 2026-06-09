if &compatible
    set nocompatible
endif

if has('syntax')
    syntax on
endif
filetype plugin indent on

if (!has("win32") || (has("vtp") && has("vcon"))) && has("termguicolor")
    set termguicolors
endif
