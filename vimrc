" Another way to send info back to the user,
" this time without a 'Hit enter' prompt

if has('popupwin')
	echow "This is a non-blocking message! (duration: 3 seconds)"
endif
