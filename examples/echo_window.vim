" Another way to send info back to the user,
" this time without a 'Hit enter' prompt

if has('popupwin')
	echow "This is a non-blocking message!"
            \ "(duration: 3 seconds)"
else
	echoh WarningMsg
	echo "This version of Vim was not compiled"
	   \ "with the '+popupwin' setting enabled"
	echoh None
endif
