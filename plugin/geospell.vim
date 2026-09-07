" geospell: a geophysics spelling dictionary, built from tracked word lists.
"
"   :GeoSpellBuild              compile words.txt into spell/geophysics.utf-8.spl
"   :GeoSpellAdd [words]        add words (default: word under cursor), rebuild
"   :GeoSpellRemove [words]     remove words and keep them out, rebuild
"   :GeoSpellHarvest [paths]    list words unknown to en_us found in files,
"                               for review; then :GeoSpellAccept
"   :GeoSpellStats              counts and build time
"
" Use it with:  set spelllang=en_us,geophysics   (see :help geospell)
if exists('g:loaded_geospell')
  finish
endif
let g:loaded_geospell = 1

" Minimum occurrences for a harvested word to be listed.
let g:geospell_min_count = get(g:, 'geospell_min_count', 2)
" Files larger than this many bytes are not scanned (data with a .txt name).
let g:geospell_max_file_size = get(g:, 'geospell_max_file_size', 3 * 1024 * 1024)

command! -bar                            GeoSpellBuild   call geospell#build()
command! -bar -nargs=*                   GeoSpellAdd     call geospell#add(<f-args>)
command! -bar -nargs=*                   GeoSpellRemove  call geospell#remove(<f-args>)
command! -bar -nargs=* -complete=file    GeoSpellHarvest call geospell#harvest(g:geospell_min_count, <f-args>)
command! -bar                            GeoSpellAccept  call geospell#accept()
command! -bar                            GeoSpellStats   call geospell#stats()

" Rebuild the dictionary when the lists are newer than it (or it is missing).
call geospell#build_if_stale()
