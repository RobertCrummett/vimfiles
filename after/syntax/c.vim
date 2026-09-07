" Also sourced for cpp (cpp.vim does 'runtime! syntax/c.vim').
" The bundled syntax only defines cFunction when c_functions is set.
if !exists('c_functions')
  syn match cFunction "\<\h\w*\ze\_s*("
endif
