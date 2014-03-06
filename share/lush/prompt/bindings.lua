module(..., package.seeall)

-- terminfo is a _filthy_ liar, thus all the fallbacks...
-- 
-- For instance:
--  * The termcap for xterm only contains the key sequences for the numpad versions of the
--    arrow keys, but xterm does not emit those normally.
--  * The Mac terminal doesn't expose a correct kbs, so we have to override with '\b'

emacs = {
	{ terminfo = 'kbs', fallback = '\b', 'delete_left' },
	{ terminfo = 'kdch1', 'delete_right' },

	{ terminfo = 'cr', fallback = '\n', 'finish' },

	{ terminfo = 'kcub1', fallback = '\027[D', 'move_left' }, -- Left arrow key
	{ terminfo = 'kcuf1', fallback = '\027[C', 'move_right' }, -- Right arrow key
	{ terminfo = 'kcuu1', fallback = '\027[A', 'history_show_prev' }, -- Up arrow key
	{ terminfo = 'kcud1', fallback = '\027[B', 'history_show_next' }, -- Down arrow key

	{ terminfo = 'khome', 'move_to_start' },
	{ terminfo = 'kend', 'move_to_end' },
	{ terminfo = 'ht', fallback = '\t', 'complete' },
}
