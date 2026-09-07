## Learning Vim

Because I always come back to this editor, I might as well study the language of the editor.

## Resources

1. [Official Vim Website](https://www.vim.org/)
2. [Learn Vim the Hard Way](https://learnvimscriptthehardway.stevelosh.com/)
3. [Tim Pope's Github](https://github.com/tpope)
4. [Vim Commands: A Beginner Guide with Examples](https://thevaluable.dev/vim-commands-beginner/)

## Local plugins

- **colors/custom.vim** — the bundled `quiet` scheme plus three accents used
  consistently across languages (lavender for functions, light purple for
  special characters/notation/options, pink for labels/links and vimscript
  keywords). Language-specific links live at the end of the file.
- **plugin/comments.vim** — `gc{motion}`, `gcc`, and `gc` in Visual mode
  toggle line comments; dot-repeatable, counts work. Leaders for ~140
  filetypes in `g:comment_map`; `b:comment_leader` overrides per buffer.
- **plugin/diredit.vim** — edit a directory as text: `:Ex [dir]`, `-` for the
  parent, `<CR>` to open. Rename by editing, delete with `dd`, copy with
  `yy`/`p`, move by writing a path or pasting into another listing, create by
  adding a line (trailing `/` for a directory); `:w` shows the plan and
  applies it. `gl` toggles details, `g.` dotfiles, `g?` help.
- **plugin/synexplore.vim** — `:SynCursor[!]`, `:SynGroup {group}`,
  `:SynHighlights [pattern]`, `:SynRules [group]` explain why text is coloured
  the way it is, in searchable buffers, with the file and line each rule or
  link came from and whether it is yours to edit.

## Thesaurus

`CTRL-X CTRL-T` in Insert mode completes synonyms through
`autoload/thesaurus.vim`, which reads `thesaurus/mthesaur.txt`. That file is
the public-domain Moby Thesaurus II by Grady Ward (Project Gutenberg ebook
3202, about 24 MB) and is not tracked. Fetch it with:

    curl -L -o thesaurus/mthesaur.txt https://www.gutenberg.org/files/3202/files/mthesaur.txt

On a whole word the menu lists its synonyms; on a partial word it lists
headwords that start with it, so complete the word first and press
`CTRL-X CTRL-T` again. The file is loaded once per session on first use.

## Tags without ctags

`:MakeTags [dir]` walks a directory tree and writes `dir/tags` using only
Vim: `plugin/tagsgen.vim` holds a table of definition patterns per filetype
(C/C++, Rust, Python, Go, JavaScript, Lua, Vim script, shell, PowerShell,
batch, MATLAB, Scheme/Racket/Lisp, Typst, TeX, Markdown headings) and
`autoload/tagsgen.vim` does the scanning. Entries use ctags' search-pattern
form, so `:tag`, `CTRL-]`, and `:tselect` work as usual and survive line
shifts. It is regex based: no scopes or overload resolution, and the odd
false positive. Add patterns or extensions through `g:tagsgen_patterns` and
`g:tagsgen_filetypes` in the vimrc.

## Help

Every local plugin has a Vim help file under `doc/`: `:help comments`,
`:help diredit`, `:help synexplore`, `:help tagsgen`, `:help thesaurus.vim`,
`:help sexptutor`, and any command by name, for example `:help :SynCursor`
or `:help :MakeTags`. The vimrc rebuilds `doc/tags` at startup, so edits to
the help files show up on the next launch; `doc/tags` itself is generated
and ignored.

## vim-sexp tutor

`:SexpTutor` opens a practice copy of `tutor/sexptutor.txt`, a
vimtutor-style course covering every vim-sexp mapping in eight chapters,
easiest first, with a cheat sheet at the end. `:SexpTutor!` opens the
original for editing.

## Geophysics spelling dictionary

`set spelllang=en_us,geophysics` adds a field-specific dictionary generated
from `spell/geophysics/words.txt` (tracked, plain text) minus
`spell/geophysics/reject.txt`. The compiled `.spl` is not tracked; it is
rebuilt at startup whenever the lists change. `:GeoSpellAdd` and
`:GeoSpellRemove` edit the lists from inside Vim, `:GeoSpellHarvest` lists
unknown words found in files for review, and `fetch-corpus.py` refreshes the
untracked corpus (Wikipedia geophysics articles, arXiv geo-ph abstracts) used
to build the base list. See `:help geospell` for the add, remove and update
workflows.

## Local LLM completion

`:LlmWarm` primes the server with the file you are about to edit. `CTRL-X CTRL-A` in Insert mode asks a local model for the next word, phrase
or line as a completion menu; `CTRL-X CTRL-B` asks for a block, streamed in
as ghost text that `CTRL-Y` accepts and `CTRL-E` drops, the same keys as the
menu. Progress is reported on the command line while the server loads or a
request runs. The plugin drives llama.cpp's
`llama-server`, starting it in the background on first use, never at
startup, and stopping it when Vim exits or crashes. The model sees the text
around the cursor plus chunks from recent jump-list positions and sibling
buffers. Weights live in `models/` (untracked); `models/registry.txt` records
where each comes from and `:LlmDownload {name}` fetches them. See `:help llm`.
