tool
class_name DebugPrint

# Based on logger implementation in Zylann's hterrain plugin
# https://github.com/Zylann/godot_heightmap_plugin/blob/master/addons/zylann.hterrain/util/logger.gd

class Base:
	const PREFIXES := {
		WARNING = '[WARNING] ',
		DEBUG   = '[Debug] ',
	}

	var base_context := ""

	func _init(p_base_context):
		base_context = p_base_context

	# (For Verbose impl)
	func debug(message: String, ctx := ""):
		pass

	func warn(message: String, ctx := ""):
		push_warning(ApplyTemplate(self, ctx, message.insert(0, PREFIXES.WARNING), false))

	func error(message: String, ctx := ""):
		push_error(ApplyTemplate(self, ctx, message))

	# Becuase `log` is not a legal literal and there's no callable instances
	func write(message: String, ctx := ""):
		print(ApplyTemplate(self, ctx, message))


	const Template := "{0}[{1}{2}] {3}"

	# Main log building function for logging methods
	static func ApplyTemplate(logger: Base, context: String, body: String, timestamp := true) -> String:
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

	func extend(context):
		return Builder.get_for(context, self)

class Verbose extends Base:
	func _init(pbase_context: String).(pbase_context):
		pass

	func debug(message: String, ctx := ""):
		print(ApplyTemplate(self, ctx, message.insert(0, PREFIXES.DEBUG)))

class Builder:
	static func get_for(context, parent: Base = null) -> Base:
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
		if parent is Base:
			context_str = context_str.insert(0, parent.base_context + ':')

		if OS.is_stdout_verbose():
			return Verbose.new(context_str)
		return Base.new(context_str)
