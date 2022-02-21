extends Node

#
# Collection of various elements in pursuit of outputting to output panel in plain text, and
# terminal styled via ansi. Atm it seems only bulletproof way is to write the plain version with
# `print`, and then completely scrub that out with `printraw` (then doing the styled output with
# `printraw` as well).
#

# Reference: http://www.climagic.org/mirrors/VT100_Escape_Codes.html
# Transformation steps:
#  - Convert descriptions to basic static methods:
#     /^(\w+)(?:\((.+?)\))?( [A-Z][A-Z\d]*)?[ ]{3,}(\S.+?) +\^\[(.+)/
#     #$3 $4\nstatic func ESC_$1($2) -> String:\n\treturn "%s$5" % [ ESC, $2 ]\n\n
#  - Replace '<' + <PARAM> + '>' syntax with basic format string
#     /<([a-z])>/
#     %s
#  - Merge/remove duplicates

const ESC = '\u001b'


# SGR0 Turn off character attributes
static func ESC_modesoff() -> String:
	return "%s[0m" % [ ESC,  ]


# SGR1 Turn bold mode on
static func ESC_bold() -> String:
	return "%s[1m" % [ ESC,  ]


# SGR2 Turn low intensity mode on
static func ESC_lowint() -> String:
	return "%s[2m" % [ ESC,  ]


# SGR4 Turn underline mode on
static func ESC_underline() -> String:
	return "%s[4m" % [ ESC,  ]


# SGR5 Turn blinking mode on
static func ESC_blink() -> String:
	return "%s[5m" % [ ESC,  ]


# SGR7 Turn reverse video on
static func ESC_reverse() -> String:
	return "%s[7m" % [ ESC,  ]


# SGR8 Turn invisible text mode on
static func ESC_invisible() -> String:
	return "%s[8m" % [ ESC,  ]


# DECSTBM Set top and bottom line#s of a window
static func ESC_setwin(pt, pb) -> String:
	return "%s[%s;%sr" % [ ESC, pt, pb  ]


# CUU Move cursor up n lines
static func ESC_cursorup(n) -> String:
	return "%s[%sA" % [ ESC, n ]


# CUD Move cursor down n lines
static func ESC_cursordn(n) -> String:
	return "%s[%sB" % [ ESC, n ]


# CUF Move cursor right n lines
static func ESC_cursorrt(n) -> String:
	return "%s[%sC" % [ ESC, n ]


# CUB Move cursor left n lines
static func ESC_cursorlf(n) -> String:
	return "%s[%sD" % [ ESC, n ]


# Move cursor to upper left corner
static func ESC_cursorhome() -> String:
	return "%s[H" % [ ESC,  ]
	# Alternate form
	# return "%s[;H" % [ ESC,  ]


# CUP Move cursor to screen location v,h
static func ESC_cursorpos(v,h) -> String:
	return "%s[%s;%sH" % [ ESC, v,h ]


# Move cursor to upper left corner
static func ESC_hvhome() -> String:
	return "%s[f" % [ ESC,  ]
	# Alternate form
	# return "%s[;f" % [ ESC,  ]


# CUP Move cursor to screen location v,h
static func ESC_hvpos(v,h) -> String:
	return "%s[%s;%sf" % [ ESC, v,h ]


# IND Move/scroll window up one line
static func ESC_index() -> String:
	return "%sD" % [ ESC,  ]


# RI Move/scroll window down one line
static func ESC_revindex() -> String:
	return "%sM" % [ ESC,  ]


# NEL Move to next line
static func ESC_nextline() -> String:
	return "%sE" % [ ESC,  ]


# DECSC Save cursor position and attributes
static func ESC_savecursor() -> String:
	return "%s7" % [ ESC,  ]


# DECSC Restore cursor position and attributes
static func ESC_restorecursor() -> String:
	return "%s8" % [ ESC,  ]



# HTS Set a tab at the current column
static func ESC_tabset() -> String:
	return "%sH" % [ ESC,  ]


# TBC Clear a tab at the current column
static func ESC_tabclr() -> String:
	return "%s[g" % [ ESC,  ]
	# Alternate form
	# return "%s[0g" % [ ESC,  ]


# TBC Clear all tabs
static func ESC_tabclrall() -> String:
	return "%s[3g" % [ ESC,  ]



# DECDHL Double-height letters, top half
static func ESC_dhtop() -> String:
	return "%s#3" % [ ESC,  ]


# DECDHL Double-height letters, bottom half
static func ESC_dhbot() -> String:
	return "%s#4" % [ ESC,  ]


# DECSWL Single width, single height letters
static func ESC_swsh() -> String:
	return "%s#5" % [ ESC,  ]


# DECDWL Double width, single height letters
static func ESC_dwsh() -> String:
	return "%s#6" % [ ESC,  ]



# EL0 Clear line from cursor right
static func ESC_cleareol() -> String:
	return "%s[K" % [ ESC,  ]
	# Alternate form
	# return "%s[0K" % [ ESC,  ]


# EL1 Clear line from cursor left
static func ESC_clearbol() -> String:
	return "%s[1K" % [ ESC,  ]


# EL2 Clear entire line
static func ESC_clearline() -> String:
	return "%s[2K" % [ ESC,  ]



# ED0 Clear screen from cursor down
static func ESC_cleareos() -> String:
	return "%s[J" % [ ESC,  ]
	# Alternate form
	# return "%s[0J" % [ ESC,  ]


# ED1 Clear screen from cursor up
static func ESC_clearbos() -> String:
	return "%s[1J" % [ ESC,  ]


# ED2 Clear entire screen
static func ESC_clearscreen() -> String:
	return "%s[2J" % [ ESC,  ]

