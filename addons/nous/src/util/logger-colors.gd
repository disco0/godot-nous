tool

const ESCAPE := "\u001B"
const COLOR_RESET := "\u001B[0m"

const BLACK := "\u001B[0;30m"
const RED := "\u001B[0;31m"
const GREEN := "\u001B[0;32m"
const YELLOW := "\u001B[0;33m"
const BLUE := "\u001B[0;34m"
const PURPLE := "\u001B[0;35m"
const CYAN := "\u001B[0;36m"
const WHITE := "\u001B[0;37m"
const BLACK_BOLD := "\u001B[1;30m"
const RED_BOLD := "\u001B[1;31m"
const GREEN_BOLD := "\u001B[1;32m"
const YELLOW_BOLD := "\u001B[1;33m"
const BLUE_BOLD := "\u001B[1;34m"
const PURPLE_BOLD := "\u001B[1;35m"
const CYAN_BOLD := "\u001B[1;36m"
const WHITE_BOLD := "\u001B[1;37m"
const BLACK_UNDERLINED := "\u001B[4;30m"
const RED_UNDERLINED := "\u001B[4;31m"
const GREEN_UNDERLINED := "\u001B[4;32m"
const YELLOW_UNDERLINED := "\u001B[4;33m"
const BLUE_UNDERLINED := "\u001B[4;34m"
const PURPLE_UNDERLINED := "\u001B[4;35m"
const CYAN_UNDERLINED := "\u001B[4;36m"
const WHITE_UNDERLINED := "\u001B[4;37m"
const BLACK_BACKGROUND := "\u001B[40m"
const RED_BACKGROUND := "\u001B[41m"
const GREEN_BACKGROUND := "\u001B[42m"
const YELLOW_BACKGROUND := "\u001B[43m"
const BLUE_BACKGROUND := "\u001B[44m"
const PURPLE_BACKGROUND := "\u001B[45m"
const CYAN_BACKGROUND := "\u001B[46m"
const WHITE_BACKGROUND := "\u001B[47m"
const BLACK_BRIGHT := "\u001B[0;90m"
const RED_BRIGHT := "\u001B[0;91m"
const GREEN_BRIGHT := "\u001B[0;92m"
const YELLOW_BRIGHT := "\u001B[0;93m"
const BLUE_BRIGHT := "\u001B[0;94m"
const PURPLE_BRIGHT := "\u001B[0;95m"
const CYAN_BRIGHT := "\u001B[0;96m"
const WHITE_BRIGHT := "\u001B[0;97m"
const BLACK_BOLD_BRIGHT := "\u001B[1;90m"
const RED_BOLD_BRIGHT := "\u001B[1;91m"
const GREEN_BOLD_BRIGHT := "\u001B[1;92m"
const YELLOW_BOLD_BRIGHT := "\u001B[1;93m"
const BLUE_BOLD_BRIGHT := "\u001B[1;94m"
const PURPLE_BOLD_BRIGHT := "\u001B[1;95m"
const CYAN_BOLD_BRIGHT := "\u001B[1;96m"
const WHITE_BOLD_BRIGHT := "\u001B[1;97m"
const BLACK_BACKGROUND_BRIGHT := "\u001B[0;100m"
const RED_BACKGROUND_BRIGHT := "\u001B[0;101m"
const GREEN_BACKGROUND_BRIGHT := "\u001B[0;102m"
const YELLOW_BACKGROUND_BRIGHT := "\u001B[0;103m"
const BLUE_BACKGROUND_BRIGHT := "\u001B[0;104m"
const PURPLE_BACKGROUND_BRIGHT := "\u001B[0;105m"
const CYAN_BACKGROUND_BRIGHT := "\u001B[0;106m"
const WHITE_BACKGROUND_BRIGHT := "\u001B[0;107m"

static func clear_console():
	match OS.get_name():
		'Windows': printraw(ESCAPE + 'c')
		_: printraw(ESCAPE + 'c')

static func _get_string(what, divider = ""):
	var string := ""
	if what is Array:
		for thing in what:
			string += String(thing) + divider
	elif what is String:
		string = what
	else:
		string = String(what)
	return string


static func line(color, what) -> void:
	set_color(color)
	print(_get_string(what))
	reset()


static func raw(color, what) -> void:
	set_color(color)
	printraw(_get_string(what))
	reset()

static func s(color, what) -> void:
	set_color(color)
	print(_get_string(what, " "))
	reset()

static func t(color, what) -> void:
	set_color(color)
	print(_get_string(what, "   "))
	reset()

static func debug(color, what) -> void:
	set_color(color)
	print(_get_string(what))
	print_stack()
	reset()

static func set_color(color):
	printraw(color)

static func reset():
	printraw(ESCAPE + COLOR_RESET)
