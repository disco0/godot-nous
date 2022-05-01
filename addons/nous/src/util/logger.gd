tool


const Colorful := preload('./logger-colors.gd')
const Options := { "USE_COLORFUL_CONSOLE": true }
const DEFAULT_COLORS := {
	BASE = Colorful.GREEN,
	CONTEXT = Colorful.GREEN,
}


# Based on logger implementation in Zylann's hterrain plugin
# https://github.com/Zylann/godot_heightmap_plugin/blob/master/addons/zylann.hterrain/util/logger.gd
class DebugPrintBase:
	const PREFIXES := {
		WARNING = '[WARNING] ',
		DEBUG   = '[Debug] ',
	}

	var base_context := ""

	func _init(p_base_context, context_color = DEFAULT_COLORS.BASE):
		base_context = p_base_context
		colors.context = context_color

	# (For Verbose impl)
	func debug(message: String, ctx := ""):
		pass

	func warn(message: String, ctx := ""):
		push_warning(ApplyTemplate(self, ctx, message.insert(0, PREFIXES.WARNING), false))

	func error(message: String, ctx := ""):
		push_error(ApplyTemplate(self, ctx, message))

	# Becuase `log` is not a legal literal and there's no callable instances
	func write(message: String, ctx := ""):
		if Options.USE_COLORFUL_CONSOLE:
			PrintStyled(self, ctx, message)
		else:
			print(ApplyTemplate(self, ctx, message))


	const Template      := "{0}[{1}{2}] {3}"
	const ColorTemplate := "%s%s%s[%s]%s %s%s"
	const Colorful = preload('./logger-colors.gd')
	const DEFAULT_COLORS := {
		BASE = Colorful.GREEN,
		CONTEXT = Colorful.GREEN,
	}

	var colors := {
		base    = DEFAULT_COLORS.BASE,
		context = DEFAULT_COLORS.CONTEXT
	}

	static func PrintStyled(logger: DebugPrintBase, context: String, body: String, timestamp := true) -> void:

		for pair in [
				[ Colorful.BLACK_BRIGHT, (TimestampPrefix() if timestamp == true else "") ],
				[ logger.colors.base, '['],
				[ logger.colors.context, logger.base_context],
				[ logger.colors.base, "%s%s" % [
						(":" + context if context != "" else ""), ']' ] ],
				[ ("%s%s" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ]), "" if body.empty() else (" " + body) ], ]:
			if pair[0]: Colorful.set_color(pair[0])
			if pair[1]: printraw(pair[1])

		printraw("%s%s\n" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ])


		# ("%s%s" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ])
		# body
		# ("%s%s" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ])
		# print(ColorTemplate % [
		# 		Colorful.BLACK_BRIGHT,
		# 		(TimestampPrefix() if timestamp == true else ""),
		# 		logger.colors.base,
		# 		(logger.colors.context
		# 			+ logger.base_context
		# 			+ logger.colors.base
		# 			+ (":" + context if context != "" else "")),
		# 		("%s%s" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ]),
		# 		body,
		# 		("%s%s" % [ Colorful.ESCAPE, Colorful.COLOR_RESET ])
		# ])


	# Main log building function for logging methods
	static func ApplyTemplate(logger: DebugPrintBase, context: String, body: String, timestamp := true) -> String:
		return Template.format([
			TimestampPrefix() if timestamp == true else "",
			logger.base_context,
			":" + context if context != "" else "",
			body
		])

	const TIMESTAMP_FORMAT = "%02d:%02d:%02d"
	static func TimestampPrefix() -> String:
		var dt = OS.get_datetime()
		return (TIMESTAMP_FORMAT + " - ") % [dt.hour, dt.minute, dt.second]

	func extend(context, context_color = null):
		if context_color:
			return Builder.get_for(context, self, context_color)
		else:
			return Builder.get_for(context, self)

class Verbose extends DebugPrintBase:
	func _init(pbase_context: String, context_color = null).(pbase_context, context_color):
		pass

	func debug(message: String, ctx := ""):
		print(ApplyTemplate(self, ctx, message.insert(0, PREFIXES.DEBUG)))

class Builder:
	static func get_for(context, parent: DebugPrintBase = null, context_color: String = DEFAULT_COLORS.BASE) -> DebugPrintBase:
		# Note: don't store the owner. If it's a Reference, it could create a cycle
		var context_str: String
		match typeof(context):
			TYPE_STRING:
				context_str = context
			TYPE_OBJECT:
				# Only expected cases afaik

				# If passed get_script()
				if context is GDScript:
					context_str = context.resource_path.get_file().get_basename()
				# If passed self
				elif context is Node:
					# Idiot check just in case
					if typeof(context.get_script()) != TYPE_OBJECT:
						push_error('Passed node instance does not contain script object.')

					context_str = context.get_script().resource_path.get_file().get_basename()

		# Allow for quick extensions
		if parent is DebugPrintBase:
			context_str = context_str.insert(0, parent.base_context + ':')

		if OS.is_stdout_verbose():
			return Verbose.new(context_str, context_color)
		return DebugPrintBase.new(context_str, context_color)
