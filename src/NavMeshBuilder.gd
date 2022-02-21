class_name NavMeshBuilder
extends EditorScript
tool

# Rewrite/refactor of original nav mesh generation procedure into separate script.
#
# Originally planned to replace deep scene cloning with (Editor|)NavigationMeshGenerator's group based
# method, but in its current form it breaks on beyond smaller test maps-until that's fully
# functioning (a refined version of) the older method will remain.
#
# @TODO: Moving into Godot 3.5 make sure to set Navigation's cell_size to whatever was used to
#        generate the mesh-not 100% on what that means yet but here's the error:
#
#     sync: Attempted to merge a navigation mesh triangle edge with another already-merged edge.
#           This happens when the Navigation's `cell_size` is different from the one used to
#           generate the navigation mesh. This will cause navigation problem.
#      - <C++ Source>  modules/navigation/nav_map.cpp:639 @ sync()
#

var dprint := CSquadUtil.dprint_for(self)

var plugin: EditorPlugin
var editor: EditorInterface

var edited: EditedScene

func _init(_plugin):
	editor = get_editor_interface()
	plugin = _plugin
	edited = EditedScene.new()

const plugin_name = 'csquad-util'
const plugin_path := "res://addons/" + plugin_name

const dprint_base_ctx := 'NavMeshBuilder'

# Value for NavigationMesh's Source Group Name (if ever tried/used eventually)
const NAVMESH_SOURCE_GROUP_NAME = 'nav-mesh'

var _level_node: Spatial

const NavigationMeshCrueltySquadBaseRes = plugin_path + "/src/res/NavigationMesh-CrueltySquadBase.tres"
const NavigationMeshCrueltySquadBase := preload(NavigationMeshCrueltySquadBaseRes)

#region TODO: Convert to exports

# Handling existing navmesh member on build
enum NAV_MESH_INIT {
	CLEAR,
	KEEP,
}

var nav_mesh_init: int = NAV_MESH_INIT.CLEAR

# Bitflags to choose collected nodes building via cloning QodotMap
enum GENMODES {
	STATIC_COLLIDERS = 1 << 0,
	MESH_INSTANCE    = 1 << 1,
}

export (int, FLAGS, "STATIC_COLLIDERS", "MESH_INSTANCE") var gen_mode = GENMODES.STATIC_COLLIDERS | GENMODES.MESH_INSTANCE

# Should really manipulate this with the actual export, but all the other UI elements connect to
# methods here so

# Base for gen_mode flag toggles
func set_genmode_flag(flag: int, value: bool) -> void:
	var current = flag_is_enabled(gen_mode, flag)
	# For debugging reverse lookup the flag name, remove this and other debugging stuff after working
	var flag_name: String
	for enum_key in GENMODES.keys():
		if flag == GENMODES[enum_key]:
			flag_name = enum_key
			break

	dprint.write('Current value of %s => %s' % [ flag_name, current ], 'set_genmode_flag')

	# Exit early if new value is same
	if value == current:
		return

	if value:
		gen_mode = set_flag(gen_mode, flag)
	else:
		gen_mode = unset_flag(gen_mode, flag)

	# Idiot check correct
	var updated = flag_is_enabled(gen_mode, flag)
	dprint.write('Updated value of %s => %s' % [ flag_name, updated ], 'set_genmode_flag')

func set_gen_with_meshinst(value: bool) -> void:
	set_genmode_flag(GENMODES.MESH_INSTANCE, value)

func set_gen_with_staticbody(value: bool) -> void:
	set_genmode_flag(GENMODES.STATIC_COLLIDERS, value)

# Build mode
enum NAVBAKEMODES {
	INSTANCE_CHILDREN,
	GROUP,
}

var bake_mode: int = NAVBAKEMODES.GROUP

# Filtering method
enum TARGETMODE {
	ENT_REGEX,
	WORLDSPAWN,
}

var target_mode: int = TARGETMODE.ENT_REGEX

enum MESH_BASE_TYPE {
	DEFAULT,
	GROUP,
}

# Whether to add group to matching entity nodes, or their children (for baking with explicit grouping)
enum NODE_GROUPING_MODE {
	NODE,
	CHILDREN,
}

var grouping_mode: int = NODE_GROUPING_MODE.NODE

#endregion TODO: Convert to exports

func InstanceNavMeshBase(type: int = MESH_BASE_TYPE.DEFAULT) -> NavigationMesh:
	var inst: NavigationMesh = NavigationMeshCrueltySquadBase.duplicate()
	# Just checked in the repl this should be only first bit
	# inst.set_collision_mask(1)

	match type:
		# Vanilla
		MESH_BASE_TYPE.DEFAULT:
			dprint.write('Building default NavigationMesh instance', 'InstanceNavMeshBase')
			inst.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_NAVMESH_CHILDREN)
			inst.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES)
			inst.set_source_group_name(NAVMESH_SOURCE_GROUP_NAME)

		# Build other flavors
		MESH_BASE_TYPE.GROUP:
			dprint.write('Building NavigationMesh instance for group based build', 'InstanceNavMeshBase')
			inst.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN)
			inst.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
			inst.set_source_group_name(NAVMESH_SOURCE_GROUP_NAME)

	return inst

#region Weakref-based Edited Scene Manager

class EditedScene:
	# Expected to be top level node (at least visually in Scene tree)
	var level: Spatial

	var level_ref:  WeakRef = weakref(null)
	var edited_ref: WeakRef = weakref(null)

	# Check if a level ref has been registered
	func _get_has_handle() -> bool:
		return is_instance_valid(level_ref.get_ref())
	var has_handle: bool setget , _get_has_handle

	# Update weakrefs, or clear by passing null
	func update(edited: Node) -> void:
		if edited == null:
			edited_ref = weakref(null)
			level_ref  = weakref(null)
		else:
			edited_ref = weakref(edited)
			level_ref  = weakref(TryResolveLevelNode(edited))

	func _set_scene_filepath(path: String) -> void:
		push_error('Tried to set filepath of scene resolved from weakref.')

	func _get_scene_filepath() -> String:
		# Check if ref is still valid, and return path of active scene
		var level_deref = self.level_ref.get_ref()
		if not level_deref:
			return ""
		return level_deref.get_tree().edited_scene_root.filename
	var scene_path: String setget , _get_scene_filepath

	func _get_cached_navmesh_filepath() -> String:
		var _scene_path = self._get_scene_filepath()
		if _scene_path:
			var nav_cache_path = FILENAME_SUFFIX_PATTERNS[NAME_SUFFIX.NAVFILE] % [ _scene_path.get_basename() ]
			print('Resolved expected nav cache file path <%s>' % [ nav_cache_path ])
			return nav_cache_path
		else:
			get_script().dprint.write('Failed to resolve nav cache path.', "EditedScene:cached_navmesh_path")
			return ""

	var cached_navmesh_path: String setget , _get_cached_navmesh_filepath

	func _get_qodot_copy_filepath() -> String:
		var _scene_path = self._get_scene_filepath()
		if _scene_path:
			return FILENAME_SUFFIX_PATTERNS[NAME_SUFFIX.QODOT_MAP_COPY] % [ _scene_path.get_basename() ]
		else:
			get_script().dprint.write('Failed to resolve qodot copy path.', "EditedScene:qodot_copy_filepath")
			return ""

	var qodot_copy_filepath: String setget , _get_qodot_copy_filepath

	func _init(node: Node = null):
		if not node is Node:
			return

	static func TryResolveLevelNode(node: Node, tailcall: bool = false) -> Spatial:
		if node is Spatial and node.name == "Level":
			return node as Spatial
		else:
			return (node.owner as Spatial
						if node.owner is Spatial and node.owner.name == "Level"
						else null)

	static func ResolveLevelNavMeshInstance(level_node: Spatial) -> NavigationMeshInstance:
		return level_node.get_node('Navigation/NavigationMeshInstance') as NavigationMeshInstance

#endregion Weakref-based Edited Scene Manager

# Expected structure:
#```
# Level
# ├─ Global Light
# ├─ Navigation
# │  └─ NavigationMeshInstance
# ├─ WorldEnvironment
# └─ QodotMap
#```
static func handles(node) -> bool:
	return node is Spatial and (
		(not (node as Node).get_owner() is Node) or node.owner.name != "Level"
	) and EditedScene.TryResolveLevelNode(node) is Spatial

#region Filename Patterns

enum NAME_SUFFIX {
	NAVFILE,
	QODOT_MAP_COPY,
}

# Format Expression Values
# %s: Level file base name
const FILENAME_SUFFIX_PATTERNS := {
	NAME_SUFFIX.NAVFILE:        "%s-nav.tres",
	NAME_SUFFIX.QODOT_MAP_COPY: "%s-nav-map.tscn",
}

#endregion Filename Patterns

#region Common

# Alternate recursive own function that validates target node is owned by
# a passed root node before changing.
#
# Modified from original:
# <https://old.reddit.com/r/godot/comments/mpwmt6/save_branch_as_scene_on_code/gui4p8e/>
static func recursive_transfer_owner(node: Node, new_owner: Node, root: Node) -> void:
	if node.owner != root:
		return
	node.set_owner(new_owner)
	for child in node.get_children():
		recursive_transfer_owner(child, new_owner, root)

# Own recursively - supporting ignoring nested instanced scenes (.filename).
# https://godotengine.org/qa/3942/how-can-i-duplicate-a-node-including-all-its-children?show=45905#a45905
static func recursive_own(node, new_owner):
	if not node == new_owner: #  and (not node.owner or node.filename):
		node.owner = new_owner
	if node.get_child_count():
		for kid in node.get_children():
			recursive_own(kid, new_owner)

# Completely overengineered pattern matching on node names
class EntityNameFilter:
	static func flag_is_enabled(bit, flag):
		return bit & flag != 0

	enum PATTERNS {
		WORLDSPAWN  = 1 << 0,
		FUNC_GROUPS = 1 << 1,
		WATER       = 1 << 2,
		MAX
	}

	const DefaultPatterns = PATTERNS.WORLDSPAWN | PATTERNS.FUNC_GROUPS


	const PatternBase = '^(?i)entity_[\\d]+_'
	static func RegexSourceWithPatterns(patterns: int) -> String:
		# Check for invalid flags (overkill, but as an exercise)
		if PATTERNS.MAX <= patterns:
			push_error('EntityNameFilter:RegexSourceWithPatterns >> pattern bit flag out of expected bounds (%s)' % [ PATTERNS.MAX ])
			return PatternBase

		var ent_frags := PoolStringArray()

		if patterns & PATTERNS.WORLDSPAWN:
			#print('[EntityNameFilter:RegexSourceWithPatterns] Adding worldspawn pattern')
			ent_frags.push_back('worldspawn')
		if patterns & PATTERNS.FUNC_GROUPS:
			#print('[EntityNameFilter:RegexSourceWithPatterns] Adding func_group pattern')
			ent_frags.push_back('func_group')
		if patterns & PATTERNS.WATER:
			#print('[EntityNameFilter:RegexSourceWithPatterns] Adding water pattern')
			ent_frags.push_back('water')

		return '%s(%s)' % [ PatternBase, ent_frags.join("|") ]

	var regex: RegEx
	func _init(pattern = DefaultPatterns):
		#print('[EntityNameFilter:on:init]')
		regex = RegEx.new()
		var compile_error: int

		var src: String
		# Handle flags as argument
		match typeof(pattern):
			TYPE_STRING:
				src = pattern
			TYPE_INT:
				src = RegexSourceWithPatterns(pattern)
			_:
				push_error('pattern argument must be a regex source or patterns bitflag set.')

		compile_error = regex.compile(src)
		if compile_error != OK:
			push_error('Failed to compile regex source: <%s>' % [ src ])

	# Checks name of node to see if should be processed for nav mesh generation
	func is_processed_in_navmesh(node) -> bool:
		return is_instance_valid(regex.search(node.name if node is Node else node))
		#if regex.search(node.name):
		#	return true
		#else:
		#	return false

var ent_filter := EntityNameFilter.new()

# Check for NavigationMeshInstance in level node, add if needed. Returns found or created (and
# added) NavigationMeshInstance or null on failure.
func validate_level_nav_node(level: Spatial) -> NavigationMeshInstance:
	# Get nav instance node
	var nav_mesh_inst_node : NavigationMeshInstance = level.get_node('Navigation/NavigationMeshInstance')
	if is_instance_valid(nav_mesh_inst_node):
		pass
	else:
		# Just create NavigationMeshInstance for now
		if level.get_node('Navigation'):
			dprint.write('- Adding missing NavigationMeshInstance node', 'validate_level_nav_node')
			nav_mesh_inst_node = NavigationMeshInstance.new()
			level.get_node('Navigation').add_child(nav_mesh_inst_node)
			# Probably unnecessary
			recursive_own(nav_mesh_inst_node, level)
		else:
			dprint.write('[WARNING] Missing both Navigation and Navigation/NavigationMeshInstance in level scene tree.', 'validate_level_nav_node')
			return null

	return nav_mesh_inst_node

# Used in all methods at start
func get_level_node_to_process() -> Node:
	var level = edited.level_ref.get_ref() as Spatial

	# @NOTE: Replaced working with WeakRefs with editor interface access for now
	# @NOTE 2: Hey dummy its not going to work if you're not editing the edited scene tree
	# var editor = get_editor_interface()
	# var level = editor.get_edited_scene_root()

	if not is_instance_valid(level):
		dprint.write('[WARNING] Failed to current Level scene root node', 'get_level_node_to_process')
		return null

	dprint.write('- Acquired Level node @%s' % [ level ], 'get_level_node_to_process')
	#dprint('  Level resource path: <%s>' % [ level.get_tree().edited_scene_root.filename ], 'get_level_node_to_process')

	return level

#endregion Common

# Clear all uses of nav mesh target group
func clear_nav_group_in_scene(node = get_level_node_to_process()) -> bool:
	if not is_instance_valid(node):
		dprint.write('[WARNING] Failed to current Level scene root node', 'clear_nav_group_in_scene')
		return false

	var grouped_nodes = node.get_tree().get_nodes_in_group(NAVMESH_SOURCE_GROUP_NAME)
	dprint.write('Clearing %s group from %s scene nodes' % [
			NAVMESH_SOURCE_GROUP_NAME, grouped_nodes.size() ], 'clear_nav_group_in_scene')

	for grouped_node in grouped_nodes:
		(grouped_node as Node).remove_from_group(NAVMESH_SOURCE_GROUP_NAME)

	node.get_tree().property_list_changed_notify()

	return true

# Add/remove group name for navmesh building to node or its children
func update_node_nav_group(node: Node, add: bool) -> void:
	if add:
		match grouping_mode:
			NODE_GROUPING_MODE.NODE:
				node.add_to_group(NAVMESH_SOURCE_GROUP_NAME, true)

			NODE_GROUPING_MODE.CHILDREN:
				for child in node.get_children():
					(child as Node).add_to_group(NAVMESH_SOURCE_GROUP_NAME, true)

	elif node.is_in_group(NAVMESH_SOURCE_GROUP_NAME):
		# @TODO: Probably should also do this to children conditionally
		node.remove_from_group(NAVMESH_SOURCE_GROUP_NAME)

# Rebuilds navigation mesh via group name targeting.
# (Fails on fullsize non-test map)
func rebuild_nav_via_group() -> bool:
	var level =  get_level_node_to_process()
	if not is_instance_valid(level):
		dprint.write('[WARNING] Failed to current Level scene root node', 'rebuild_nav_via_group')
		return false

	var nav_mesh_inst_node = validate_level_nav_node(level)
	if not is_instance_valid(nav_mesh_inst_node):
		dprint.write('[WARNING] Failed NavigationMeshInstance validation', 'rebuild_nav_via_group')
		level = null
		return false

	# Clear existing navmesh member (otherwise new replacement doesn't seem to stick)
	if is_instance_valid(nav_mesh_inst_node.navmesh):
		nav_mesh_inst_node.navmesh = null

	# Get map node
	var map_node = level.get_node('QodotMap')
	if not is_instance_valid(map_node):
		dprint.write('[WARNING] Failed get QodotMap node', 'rebuild_nav_via_group')
		level = null
		return false

	# Remove existing child node of QodotMap in NavMeshInstance if found
	# @NOTE: Clears everything out for now
	dprint.write('Removing any existing children in NavigationMeshInstance', 'rebuild_nav_via_group')
	for child in nav_mesh_inst_node.get_children():
		nav_mesh_inst_node.remove_child(child)
		(child as Node).queue_free()

	match target_mode:
		TARGETMODE.ENT_REGEX:
			dprint.write('Searching for entities with names matching %s' % [ ent_filter.regex.get_pattern() ])
			# Walk through map child nodes, add all relevant entity types to navmesh target group
			var add: bool = false;
			for ent_node in map_node.get_children():
				add = ent_filter.is_processed_in_navmesh(ent_node)
				if add:
					dprint.write('    -> %s' % [ ent_node ], 'rebuild_nav_via_group')
				update_node_nav_group(ent_node, add)

		TARGETMODE.WORLDSPAWN:
			# Walk through map child nodes, only add worldspawn (testing as workaround for crashing)
			for ent_node in map_node.get_children():
				if (ent_node.name as String).matchn('*worldspawn*'):
					dprint.write('    -> [WORLDSPAWN] %s' % [ ent_node ], 'rebuild_nav_via_group')
					update_node_nav_group(ent_node, true)

	dprint.write('- Generating navmesh', 'rebuild_nav_via_group')

	nav_mesh_inst_node.set_navigation_mesh(InstanceNavMeshBase(MESH_BASE_TYPE.GROUP))

	# Manually set these now since there's an export
	match gen_mode:
		GENMODES.STATIC_COLLIDERS:
			dprint.write('  - Targeting collision shapes', 'rebuild_nav_via_group')
			nav_mesh_inst_node.navmesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)

		GENMODES.MESH_INSTANCE:
			dprint.write('  - Targeting mesh instances', 'rebuild_nav_via_group')
			nav_mesh_inst_node.navmesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES)

		_:
			if gen_mode == GENMODES.STATIC_COLLIDERS | GENMODES.MESH_INSTANCE:
				dprint.write('  - Targeting collision shapes and mesh instances', 'rebuild_nav_via_group')
				nav_mesh_inst_node.navmesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_BOTH)
			else:
				push_warning('Invalid gen_mode flags %s' % [ gen_mode ])

	# Update to explicit group targeting if children are being targeted directly.
	if grouping_mode == NODE_GROUPING_MODE.CHILDREN:
		dprint.write('  - Entity children have been grouped directly, updating navmesh geometry mode to SOURCE_GEOMETRY_GROUPS_EXPLICIT', 'rebuild_nav_via_group')
		nav_mesh_inst_node.navmesh.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT)

	# Just in case
	nav_mesh_inst_node.enabled = true

	nav_mesh_inst_node.property_list_changed_notify()

	var meshgen = CSquadUtil.NavGenerator.new()

	dprint.write('  - Clearing existing NavigationMesh', 'rebuild_nav_via_group')
	meshgen.clear(nav_mesh_inst_node.navmesh)

	var grouped_node_count : int = level.get_tree().get_nodes_in_group(NAVMESH_SOURCE_GROUP_NAME).size()
	dprint.write('  - Attemping immediate bake using %s nodes in group %s' % [
			grouped_node_count, NAVMESH_SOURCE_GROUP_NAME ], 'rebuild_nav_via_group')

	dprint.write('  - Starting bake', 'rebuild_nav_via_group')
	meshgen.bake(nav_mesh_inst_node.navmesh, level)

	dprint.write('  - Bake complete, generated mesh with %s polygons' % [ nav_mesh_inst_node.navmesh.get_polygon_count() ], 'rebuild_nav_via_group')

	level = null

	return true

# Scan entity node children for CollisionShape nodes, and store in passed array
func collect_entity_collision_shapes(col: Array, node: Node) -> void:
	if node.get_child_count():
		for child in node.get_children():
			if child is CollisionShape:
				col.push_back(child)
				# often more than one CollisionShape, so continue

# Collect of all relevant CollisionShape nodes in passed QodotMap
func collect_map_nav_collision_shapes(map_node: QodotMap, node_array: Array = [ ]) -> Array: # CollisionShape[]
	if not map_node is QodotMap:
		push_error('passed non-QodotMap entity.')
		return [ ]
	elif map_node.get_child_count() == 0:
		push_error('QodotMap entity has no children.')
		return [ ]

	var cols = [ ]

	if not map_node.get_child_count() > 0:
		push_error('QodotMap entity has no children.')
		return [ ]

	for ent in map_node.get_children():
		if ent_filter.is_processed_in_navmesh(ent):
			dprint.write(' - Collecting CollisionShapes for @%s' % [ ent.name ], 'collect_map_nav_collision_shapes')
			collect_entity_mesh_instances(node_array, ent)
		else:
			pass
			# dprint(' - Skipping @%s' % [ ent.name ], 'collect_map_nav_collision_shapes')

	return node_array

# Scan entity node children for MeshInstance nodes, and store in passed array
func collect_entity_mesh_instances(col: Array, node: Node) -> void:
	if node.get_child_count():
		for child in node.get_children():
			if child is MeshInstance:
				col.push_back(child)
				# (For now,) Qodot only ever places one MeshInstance in relevant nodes
				return

# Builds array of all relevant MeshInstance nodes in passed QodotMap
func collect_map_nav_mesh_instances(map_node: QodotMap, node_array: Array = [ ]) -> Array: # MeshInstance[]
	if not map_node is QodotMap:
		push_error('passed non-QodotMap entity.')
		return [ ]
	elif map_node.get_child_count() == 0:
		push_error('QodotMap entity has no children.')
		return [ ]

	for ent in map_node.get_children():
		if ent_filter.is_processed_in_navmesh(ent):
			dprint.write(' - Collecting MeshInstance for @%s' % [ ent.name ], 'collect_map_nav_mesh_instances')
			collect_entity_mesh_instances(node_array, ent)
		else:
			pass
			# dprint(' - Skipping @%s' % [ ent.name ], 'collect_map_nav_mesh_instances')

	return node_array

# Generate filtered QodotMap node for later parenting by Level scene's NavigationMeshInstance
func build_nav_mesh_instance_child(map_node: QodotMap, level: Node = get_level_node_to_process()) -> QodotMap:
	# Shallow copy top level
	var nav_map_node = map_node.duplicate(
		Node.DUPLICATE_USE_INSTANCING | Node.DUPLICATE_GROUPS)

	dprint.write('Duplicated QodotMap base node, clearing its children.', 'build_nav_mesh_instance_child')
	for child in nav_map_node.get_children():
		nav_map_node.remove_child(child)

	var nav_nodes: Array = [ ]

	if gen_mode & GENMODES.STATIC_COLLIDERS:
		collect_map_nav_collision_shapes(map_node, nav_nodes)

	if gen_mode & GENMODES.MESH_INSTANCE:
		collect_map_nav_mesh_instances(map_node, nav_nodes)

	if nav_nodes.size() == 0:
		push_error('Collection array is empty.')
		return null

	var nav_node_parent

	# Create child StaticBody to place collision shapes in
	var static_body = StaticBody.new()
	nav_map_node.add_child(static_body)
	nav_node_parent = static_body
	static_body.set_owner(nav_map_node)

	# nav_node_parent = nav_map_node
	dprint.write('Building NavigationMeshInstance Map Proxy', 'build_nav_mesh_instance_child')

	var shape_copy: Spatial
	# Iterate through target children, translating them into global space(?)
	for shape in nav_nodes:
		shape_copy = shape.duplicate()

		# Thought this was needed for reason in comment above origin assignment below, not sure
		# anymore
		shape_copy.set_as_toplevel(true)

		# Needed or?
		if shape_copy.get_parent():
			shape_copy.get_parent().remove_child(shape_copy)

		nav_node_parent.add_child(shape_copy)
		# Transfer original global origin
		shape_copy.global_transform.origin = (shape as Spatial).global_transform.origin

	# Recursive own at the end
	dprint.write("Recursively updating NavigationMeshInstance Map Proxy children's owners to scene root", 'build_nav_mesh_instance_child')
	recursive_own(nav_map_node, level)

	dprint.write('- Generated navmesh QodotEntity child, with %s children:' % [
			# Update if StaticBody no longer used as parent for collected nodes
			nav_map_node.get_child(0).get_child_count()
		], 'build_nav_mesh_instance_child')

	return nav_map_node

func save_nav_mesh_resource(navmesh: NavigationMesh, path: String) -> bool:
	# Save new navmesh to cache file if valid and not empty
	if is_instance_valid(navmesh):
		if navmesh.get_polygon_count() == 0:
			dprint.write('[WARNING] navmesh is valid but has no vertices, returning success but skipping save to resource.', 'save_nav_mesh_resource')
			return true

		var globalized_cache_path: String = ProjectSettings.globalize_path(path)
		if path and globalized_cache_path:
			dprint.write('- Saving new navmesh to file cache <%s>' % [ path ], 'save_nav_mesh_resource')
			var save_err = -1
			save_err = ResourceSaver.save(globalized_cache_path, navmesh)
			if save_err != OK:
				dprint.write('  - Saving copy of new NavigationMesh failed, error #%s' % [ save_err ], 'save_nav_mesh_resource')
				return false

	else:
		dprint.write('[WARNING] navmesh passed is not valid instance.', 'save_nav_mesh_resource')
		return false

	return true

# Currently just the original code from nav mesh generative build method. Parameters are just
# variables no longer in scope after ripping it out (in order of LSP errors) and should be replaced
# with something that makes sense, same for return value
func save_level_to_resource(map_navmesh_child, nav_mesh_inst_node, level, map_node):

	var rel_qodot_clone_path = edited.qodot_copy_filepath
	var qodot_clone_path = ProjectSettings.globalize_path(rel_qodot_clone_path)
	dprint.write('- Saving navigation copy QodotMap to resource <%s>' % [ qodot_clone_path ], 'rebuild_nav_via_gen')
	var scene = PackedScene.new()
	dprint.write('  - Packing QodotMap node', 'rebuild_nav_via_gen')
	scene.pack(map_navmesh_child)
	dprint.write('  - Saving resource to <%s>' % [ qodot_clone_path ], 'rebuild_nav_via_gen')
	# @TODO test ResourceSaver.FLAG_RELATIVE_PATHS flag
	var save_err = ResourceSaver.save(qodot_clone_path, scene)
	if save_err != OK:
		dprint.write('  - Save failed, error #%s' % [ save_err ], 'rebuild_nav_via_gen')
		map_node.set('visible', true)
		return false

	# Debug test: remove original reowned copy from memory and see what explodes
	map_navmesh_child.free()

	dprint.write('  - Save Complete.', 'rebuild_nav_via_gen')

	dprint.write('- Loading map copy from created resource.', 'rebuild_nav_via_gen')
	var map_res_instance = load(rel_qodot_clone_path).instance() as QodotMap
	nav_mesh_inst_node.add_child(map_res_instance)
	map_res_instance.owner = level

	dprint.write('- Building navmesh', 'rebuild_nav_via_gen')
	if not is_instance_valid(nav_mesh_inst_node.navmesh):
		nav_mesh_inst_node.navmesh = InstanceNavMeshBase()

	# var nav: Navigation = nav_mesh_inst_node.get_parent() as Navigation
	var meshgen = CSquadUtil.NavGenerator.new()
	# dprint('  - Clearing existing mesh', 'rebuild_nav')
	# meshgen.clear(nav)
	dprint.write('  - Attemping immediate bake', 'rebuild_nav_via_gen')
	meshgen.bake(nav_mesh_inst_node.navmesh, nav_mesh_inst_node)
	dprint.write('  - End of immediate bake', 'rebuild_nav_via_gen')

	dprint.write('- Removing QodotMap reference from NavigationMeshInstance', 'rebuild_nav_via_gen')
	nav_mesh_inst_node.remove_child(map_res_instance)

	map_node.set('visible', true)

	var navmesh : NavigationMesh = nav_mesh_inst_node.navmesh

	save_nav_mesh_resource(navmesh, edited.cached_navmesh_path)

func rebuild_nav_via_gen() -> bool:
	var level =  get_level_node_to_process()
	if not is_instance_valid(level):
		dprint.write('[WARNING] Failed to current Level scene root node', 'rebuild_nav_via_gen')
		return false

	dprint.write('- Acquired Level node @%s' % [ level ], 'rebuild_nav_via_gen')
	dprint.write('  Level resource path: <%s>' % [ level.get_tree().edited_scene_root.filename ], 'rebuild_nav_via_gen')

	var nav_mesh_inst_node = validate_level_nav_node(level)
	if not is_instance_valid(nav_mesh_inst_node):
		dprint.write('[WARNING] Failed NavigationMeshInstance validation', 'rebuild_nav_via_gen')
		return false

	# Get map node
	var map_node = level.get_node('QodotMap')
	if not is_instance_valid(map_node):
		dprint.write('[WARNING] Failed get QodotMap node', 'rebuild_nav_via_gen')
		return false

	dprint.write('Removing any existing children in NavigationMeshInstance', 'rebuild_nav_via_gen')
	for child in nav_mesh_inst_node.get_children():
		nav_mesh_inst_node.remove_child(child)

#	map_node.set('visible', false)

	dprint.write('- Generating trimmed QodotEntity for NavigationMeshInstance:', 'rebuild_nav_via_gen')
	var map_navmesh_child := build_nav_mesh_instance_child(map_node, level)

	dprint.write('- Creating NavigationMesh for NavigationMeshInstance', 'rebuild_nav_via_gen')
	nav_mesh_inst_node.navmesh = InstanceNavMeshBase(MESH_BASE_TYPE.DEFAULT)

	# May not be needed
	if map_navmesh_child.get_parent():
		map_navmesh_child.get_parent().remove_child(map_navmesh_child)
	nav_mesh_inst_node.add_child(map_navmesh_child)

	#match gen_mode:
	#	GENMODES.STATIC_COLLIDERS:
	#		(nav_mesh_inst_node.navmesh as NavigationMesh).set_parsed_geometry_type(
	#				NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	#
	#	GENMODES.MESH_INSTANCE:
	#		(nav_mesh_inst_node.navmesh as NavigationMesh).set_parsed_geometry_type(
	#				NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES)
	#
	#	_:
	#		(nav_mesh_inst_node.navmesh as NavigationMesh).set_parsed_geometry_type(
	#				NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES)

	recursive_own(map_navmesh_child, level)

	var meshgen = CSquadUtil.NavGenerator.new()

	dprint.write('  - Attemping immediate bake', 'rebuild_nav_via_gen')

	meshgen.bake(nav_mesh_inst_node.navmesh, map_navmesh_child)

	dprint.write('  - End of immediate bake', 'rebuild_nav_via_gen')

	dprint.write('- TOOD: Restore packing generated CollisionShapes version of map.', 'rebuild_nav_via_gen')

	map_node.set('visible', true)

	dprint.write('- Complete.', 'rebuild_nav_via_gen')
	return true

func rebuild_nav(mode := bake_mode) -> bool:
	match mode:
		NAVBAKEMODES.GROUP:
			dprint.write('Rebuilding with group tagging method', 'rebuild_nav')
			return rebuild_nav_via_group()

		NAVBAKEMODES.INSTANCE_CHILDREN:
			dprint.write('Rebuilding with generation method', 'rebuild_nav')
			return rebuild_nav_via_gen()

		_:
			dprint.write('Defaulting to group tagging method', 'rebuild_nav')
			return rebuild_nav_via_group()

#region Cache File Functions

func navcache_load_cached() -> void:
	if not is_instance_valid(edited):
		dprint.write('Invalid edited member.', 'navcache_load_cached')

	var nav_cached_path = edited.cached_navmesh_path

	var level = get_level_node_to_process()
	if not is_instance_valid(level):
		dprint.write('[WARNING] Failed to get dereferenced copy of Level parent node', 'navcache_load_cached')
		return

	# Load cached navmesh scene
	var nav_cache_tscn = load(nav_cached_path)
	if not is_instance_valid(nav_cache_tscn):
		dprint.write('[WARNING] Failed to load cached nav mesh .tscn (<%s>)' % [ nav_cached_path ], 'navcache_load_cached')
		return

	# Get target node
	var nav_mesh_inst_node = level.get_node('Navigation/NavigationMeshInstance')
	if not is_instance_valid(nav_mesh_inst_node):
		dprint.write('[WARNING] Failed to walk node tree to NavigationMeshInstance child', 'navcache_load_cached')
		return

	# Restore cached for level
	nav_mesh_inst_node.navmesh = nav_cache_tscn.duplicate()

	# Signal changes
	nav_mesh_inst_node.property_list_changed_notify()

func navcache_save_cached() -> bool:
	if not is_instance_valid(edited):
		dprint.write('Invalid edited member.', 'navcache_load_cached')

	var level = get_level_node_to_process()
	if not is_instance_valid(level):
		dprint.write('[WARNING] Failed to get dereferenced copy of Level parent node', 'navcache_save_cached')
		return false

	dprint.write('Passing navigation mesh to save handler', 'navcache_save_cached')
	var mesh_inst: NavigationMeshInstance = level.get_node('Navigation/NavigationMeshInstance')
	if is_instance_valid(mesh_inst) and mesh_inst is NavigationMeshInstance:
		# (All checks on actual navmesh member done in save handler for now)
		return save_nav_mesh_resource(mesh_inst.navmesh, edited.cached_navmesh_path)
	else:
		dprint.write('[WARNING] Failed to get/validate NavigationMeshInstance node in level scene.', 'navcache_save_cached')
		return false

#endregion Cache File Functions

#region UI Signal Handlers

# Handler for all relevant changes received from UI signal.
# @NOTE: Resisting the urge to break each setting into a method, but maybe do it if this
#        goes overboard
func on_UI_build_setting_update(value, setting: int) -> void:
	dprint.write('Received params { setting: %s, value: %s } ' % [ setting, value ], 'on:UI_build_setting_update')
	match setting:
		0: # NavMeshBuilderContainer.GEN_SETTING.PARSED_GEOMETRY:
			if typeof(value) == TYPE_INT:
				# Fuck me why is it 0 indexed in the Control editor and 1 indexed here
				if value >= 0 and value <= 2: # GENMODES.size():
					match value:
						0:
							gen_mode = GENMODES.STATIC_COLLIDERS
							dprint.write('gen_mode updated to STATIC_COLLIDERS from settings UI', 'on_UI_build_setting_update')
						1:
							gen_mode = GENMODES.MESH_INSTANCE
							dprint.write('gen_mode updated to MESH_INSTANCE from settings UI', 'on_UI_build_setting_update')
						2:
							gen_mode = GENMODES.STATIC_COLLIDERS | GENMODES.MESH_INSTANCE
							dprint.write('gen_mode updated to STATIC_COLLIDERS | MESH_INSTANCE from settings UI', 'on_UI_build_setting_update')
				else:
					push_error('Invalid option button index received from UI: %s' % [ value ])
			else:
				push_error('Received non-int value from UI for parsed geometry: %s' % [ value ])

		1: # NavMeshBuilderContainer.GEN_SETTING.WORLDSPAWN_ONLY:
			if value:
				target_mode = TARGETMODE.WORLDSPAWN
			else:
				target_mode = TARGETMODE.ENT_REGEX

func on_UI_build_navmesh() -> void:
	dprint.write('Received signal to build navmesh', 'on_UI_build_navmesh')
	rebuild_nav()

func on_UI_save_navmesh() -> void:
	dprint.write('Received signal to save navmesh', 'on_UI_save_navmesh')
	navcache_save_cached()

func on_UI_load_navmesh() -> void:
	dprint.write('Received signal to restore navmesh', 'on_UI_load_navmesh')
	navcache_load_cached()

#endregion UI Signal Handlers

#region Bit Flag Utils

# From https://old.reddit.com/r/godot/comments/hb382k/bitwise_operations_bit_flags/

static func flag_is_enabled(b: int, flag: int) -> bool:
	return b & flag != 0

static func set_flag(b: int, flag: int) -> int:
	b = b | flag
	return b

static func unset_flag(b: int, flag: int) -> int:
	b = b & ~flag
	return b

#endregion Bit Flag Utils
