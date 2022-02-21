tool
class_name SignalUtil

static func DisconnectIfConnected(obj: Object, obj_signal: String, target: Object, target_method: String) -> void:
	if obj and target:
		if obj.is_connected(obj_signal, target, target_method):
			if 'dprint' in target:
				target.dprint.call(
					'write',
						'(%s).%s disconnecting from %s@%s' % [
								target.get_name(),
								target_method,
								obj,
								obj_signal
						],
						'##DisconnectIfConnected')
			obj.disconnect(obj_signal, target, target_method)

