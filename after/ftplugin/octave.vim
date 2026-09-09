" Layered on $VIMRUNTIME/ftplugin/octave.vim. Octave files get the same two
" things after/ftplugin/matlab.vim gives Matlab files: K for Matlab's help,
" and :make through the warm session (the abbreviation in
" plugin/matlabserver.vim fires for octave buffers too, and :MatlabMake
" reads this buffer's 'errorformat', which only compiler/matlab.vim sets).

setlocal keywordprg=:MatlabDoc

compiler matlab

let b:undo_ftplugin = (empty(get(b:, 'undo_ftplugin', '')) ? '' : b:undo_ftplugin . ' | ')
  \ . 'setlocal keywordprg< makeprg< errorformat< | unlet! b:current_compiler'
