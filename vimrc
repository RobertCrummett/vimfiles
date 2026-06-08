" Notice space is input between the expressions of echo
echo "the value of 'shell' is" &shell "\n"

" Nothing (n) is added!
echon "the value of 'shell' is " &shell "\n"

" Highlighting
echoh WarningMsg | echo "Don't panic\n" | echoh None

" Persistant messages can be viewed from :messages
echom "Nothing is wrong"

" A friendly ascii art cat
echo ">^.^<"
