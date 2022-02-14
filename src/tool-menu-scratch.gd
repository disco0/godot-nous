extends EditorScript
tool

var plugin: EditorPlugin
func _init(plugin: EditorPlugin):
	self.plugin = plugin
	FGDSearchTests.new().run()

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
