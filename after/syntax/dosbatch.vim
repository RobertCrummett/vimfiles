" Clear existing comment rule
syntax clear dosbatchRemComment

" Redefine without @dosbatchNumber in the contains list
syntax match dosbatchRemComment /^rem\($\|\s.*$\)/ms=s+3,lc=3 contains=dosbatchTodo,dosbatchSpecialChar,dosbatchVariable,dosBatchArgument,@Spell
syntax match dosbatchRemComment /^@rem\($\|\s.*$\)/ms=s+4,lc=4 contains=dosbatchTodo,dosbatchVariable,dosBatchArgument,@Spell
syntax match dosbatchRemComment /\srem\($\|\s.*$\)/ms=s+4,lc=4 contains=dosbatchTodo,dosbatchSpecialChar,dosbatchVariable,dosBatchArgument,@Spell
syntax match dosbatchRemComment /\s@rem\($\|\s.*$\)/ms=s+5,lc=5 contains=dosbatchTodo,dosbatchVariable,dosBatchArgument,@Spell
