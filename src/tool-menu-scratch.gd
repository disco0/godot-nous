tool
extends EditorScript

var dprint := CSquadUtil.dprint_for('tool-menu-scratch')

var run_count := 0
func _run() -> void:
	run_count += 1
	dprint.write('Run #%02d' % [ run_count ], 'on:run')

var plugin: EditorPlugin
func _init(plugin: EditorPlugin):
	self.plugin = plugin

	packed_scene_test()


#section PackedScene Search

func packed_scene_test():
	var test_scene = CSquadUtil.fgd.get_fgd_classes()[10].scene_file

	var scene_data := PackedSceneData.new(test_scene)
	var data := scene_data.data
	var node_count := data.get_node_count()
	for idx in node_count:
		var node_type_str := data.get_node_type(idx)
		#if data.get_node_type(idx).empty():
		#	continue
		dprint.write('[%s] %s' % [
			"<PACKED>" if scene_data.is_packed_scene(idx) else node_type_str,
			('%s' % [ data.get_node_path(idx) ]).plus_file(data.get_node_name(idx)),
		], 'scene')

class PackedSceneData:
	var excluded_extensions = ["godot","import", "png","mesh"]
	var type_whitelist := [
		Mesh,
		Material,
		Texture
	]

	var data: SceneState

	func _init(packed: PackedScene):
		data = packed.get_state()

	func is_packed_scene(node_idx: int) -> bool:
		return data.get_node_type(node_idx).empty()

class PackedSceneChild:
	var root: PackedSceneData
	var base_path := ""
	var scene: PackedScene
	var type_whitelist_override := [ ]
	var data: SceneState

	func _init(packed_scene: PackedScene, path, root: PackedSceneData):
		self.scene = packed_scene
		self.root = root
		self.base_path = path
		self.data = packed_scene.get_state()


func is_one_of_types(object, types):
	for type in types:
		if object is type:
			return true
	return false

#section FGD Search

class FGDSearchTests:
	func _init():
		pass

	func run() -> void:
		var searcher := FGDEntitySceneSearch.new()
		searcher.collect_entity_scenes()
		var idx := 0
		var size = searcher.point_ents.values().size()
		for ent in searcher.point_ents.values():
			idx += 1
			print('[%03d/%03d] %s%s => %s' % [
					idx + 1,
					size,
					ent.name,
					' '.repeat(25 - len(ent.name)),
					ent.scene_file.resource_path
				])


#section RegexTests

var RegexTests: PoolStringArray = """
load('path')
load("path")
load("extremely/dumb\\"path.file_ext")
""".split("\n", false)
class RegexTest:
	var tests: PoolStringArray
	var regex_pattern = "^[\\s]*(load[\\(])[\\s]*(['\"])(?<path>(?:[^\\n'\"\\\\]+|[\\\\]\\2|(?!\\2).)+)(\\2)[\\s]*([\\)])"
	var regex: RegEx

	func _init(tests: PoolStringArray) -> void:
		self.tests = tests
		regex = RegEx.new()
		if regex.compile(regex_pattern) != OK:
			push_error('Failed to compile pattern: <%s>' % [ regex_pattern ])
			return

		print("Tests:\n%s" %  [ tests.join('\n')])

		_run()

	func _run() -> void:

		var group_count := regex.get_group_count()
		var test_cnt := tests.size()
		for idx in test_cnt:
			var test = tests[idx]
			print('[%2d/%2d]' % [ idx + 1, test_cnt ])
			print('<%s>' % [ test ])
			var matched = regex.search(test)
			if not matched:
				push_warning('Failed to match.')
				continue

			for group_idx in group_count:
				print('  - <%s>' % [ matched.get_string(group_idx) ])
