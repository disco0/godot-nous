tool
class_name EntityMeshExtractor

const ANIMATION_SEARCH_OVERRIDE_DISABLED := true

#
# Pseudo-abstract base class for defining an extractor. Implemenation clases should
# define an Instance static method to properly set details (see PlayerMeshExtractor as an
# example)
#

func get_class() -> String:
	return '@EntityMeshExtractor'

func _init():
	set_name(get_class())

var name: String = get_class() setget set_name, _get_name
func _get_name() -> String:
	return name

var dprint := DebugPrint.Builder.get_for(self)

# Should be used by implementation classes to set extractor label/info
func set_name(value: String):
	name = value
	dprint.base_context = name

# Phase this out with extractor type (class_name)
var extractor_name setget , _get_name

var extractor_type: String setget , _get_extractor_type
func _get_extractor_type() -> String:
	return name.trim_suffix('MeshExtractor')

# Top level node of a scene to process (not 100% on using this yet)
var target: Node
# List of node names able to be processed by extractor definition
var target_node_names: Array # Array<String>

# Main implementation for each resolver's scene form. Effectively a virtual function that
# _must_ be defined by extended class
func resolve_meshes(node: Node = target) -> Array: # Array<Mesh>
	dprint.error('Method must be overridden.', 'resolve_meshes')
	return [ ]

func can_target(node: Node) -> bool:
	dprint.error('Method must be overridden.', 'can_target')
	dprint.write('Method must be overridden.', 'can_target')
	return false

# Basic helper methods

var SeenChildNodePaths := [ ] # Array<String>
# For storing top level node for debug logging
var AllChildMeshes_top: Node
func AllChildMeshes_FormatPath(node: Node) -> String:
	if ACM_in_tree:
		return "<OUT OF TREE>"
	return '#%s/%s' % [
		AllChildMeshes_top.name,
		AllChildMeshes_top.get_path_to(node)
	]
var AllChildMeshes_base: Spatial
# global_transform of base node
var AllChildMeshes_origin: Vector3
var AllChildMeshes_init_transform: Transform
var ACM_in_tree := false

# static func GlobalizeMeshCoord(node: Node, mesh: Mesh) -> Mesh:
	# var mt = MeshDataTool.new()

# Recursively collect all child meshes and store in array. Will also check if base node
# is MeshInstance.
#
# I realized as I was writing this that visibility is not a base Node member, but on Spatial-
# for now stop recursion if node given is not a Spatial, and later consider migrating all the
# typing for processing these nodes to Spatial.
# @NOTE: Need to figure out how to properly collect/transfer transform information to
#        `ProcessMesh` later on in ObjExport-atm adding a node name whitelist to work around
#        issues with the player entity's glasses not coming out right (if node_name_whitelist
#        is empty it will be passed as null to helper function, and then ignored).
func AllChildMeshes(base_node: Spatial, meshes: Array, only_visible: bool = true, node_name_whitelist := [ ]):
	# Initialize state
	SeenChildNodePaths = [ ]
	AllChildMeshes_base = base_node
	ACM_in_tree = base_node.is_inside_tree()
	AllChildMeshes_init_transform = base_node.global_transform if ACM_in_tree else base_node.transform
	AllChildMeshes_origin = AllChildMeshes_init_transform.origin
	AllChildMeshes_top = base_node # base_node.get_tree().edited_scene_root if ACM_in_tree else base_node
	_AllChildMeshes(base_node, meshes, null if node_name_whitelist.size() == 0 else node_name_whitelist, only_visible)


func AllChildMeshes_mark_seen(node: Node):
	if not AllChildMeshes_base.is_inside_tree():
		return


func AllChildMeshes_seen(node: Node) -> bool:
	if not AllChildMeshes_base.is_inside_tree():
		return false
	else:
		return SeenChildNodePaths.has(node.get_path())


func _AllChildMeshes(node: Node, meshes: Array, node_name_whitelist, only_visible: bool = true):
	if not (node is Spatial):
		if ACM_in_tree:
			# Add a debug message for now
			dprint.write('Recursed node does not inherit spatial: @%s' % [ AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
		return

	var minst: MeshInstance
	if (node is MeshInstance) and \
			(not only_visible or (node as Spatial).visible) and \
			(typeof(node_name_whitelist) != TYPE_ARRAY or node_name_whitelist.has(node.name)):
		minst = node # Just for LSP, unnecessary

		if AllChildMeshes_seen(minst):
			dprint.write("MeshInstance's mesh already already added: @%s" % [ AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
		else:
			# Check for override
			var override = minst.get_active_material(0)

			#if ACM_in_tree:
			#	dprint.write('Recording mesh at global pos %s' % [ minst.global_transform.origin ], '#AllChildMeshes')
			#else:
			#	dprint.write('Recording mesh at global pos %s' % [ minst.transform.origin ], '#AllChildMeshes')

			# Originaly handled overrides differently, just keeping the if blocks for logging now
			#if is_instance_valid(override):
			#	dprint.write("Pushing mesh info with override from node: @%s" % [AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
			#else:
			#	dprint.write("Pushing mesh info from node: @%s" % [AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')

			if ACM_in_tree:
				meshes.push_back(MeshUtils.MeshInfoTuple(node.mesh, override, minst.global_transform.origin - AllChildMeshes_origin))
			else:
				# In its current form this won't be right (to be computed relative to parent), just separating it for now
				meshes.push_back(MeshUtils.MeshInfoTuple(node.mesh, override, minst.transform.origin - AllChildMeshes_origin))
			AllChildMeshes_mark_seen(minst)

	if node.get_child_count() == 0: return

	for child in node.get_children():
		_AllChildMeshes(child, meshes, node_name_whitelist, only_visible)


func find_node_outside_tree(node: Node, path: String) -> Node:
	if node.get_child_count() == 0:
		dprint.write('Node %s has no children.' % [ node ], 'find_node_outside_tree')
		return null

	# For debug printing, remove later
	var indent := 0

	var curr := node

	var npath := NodePath(path)
	var segment_count := npath.get_name_count()

	var resolved: Node

	for idx in segment_count:
		# Set target
		var node_name := npath.get_name(idx)

		# Check flag
		var found := false

		# Search for target
		dprint.write('%sSearching through %d children' % [
					 '  '.repeat(indent), curr.get_child_count()
				], 'find_node_outside_tree')
		for child_idx in curr.get_child_count():

			var child := curr.get_child(child_idx)
			var child_name := child.name
			# Found
			if child.name == node_name:
				# Update depth (and returned value)
				curr = child
				resolved = child
				#dprint.write('%s- %s' % [ '  '.repeat(indent), child ], 'find_node_outside_tree')
				found = true
				indent += 1
				break
			else:
				pass
				#dprint.write('%sx %s != %s' % [ '  '.repeat(indent), child_name, node_name ], 'find_node_outside_tree')

		if not found:
			#dprint.warn('%s- %s <Not Found>' % [ '  '.repeat(indent), node_name ], 'find_node_outside_tree')
			return null

	return resolved

