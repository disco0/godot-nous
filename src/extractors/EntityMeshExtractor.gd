class_name EntityMeshExtractor

var dprint_conf: Dictionary = { Base = 'EntityMeshExtractor' }
func dprint(msg: String, ctx: String = "") -> void:
	print('[%s] %s' % [
		'%s%s' % [ dprint_conf['Base'], ":" + ctx if len(ctx) > 0 else "" ],
		msg
	])
	
#
# Pseudo-abstract base class for defining an extractor. Implemenation clases should
# define an Instance static method to properly set details (see PlayerMeshExtractor as an
# example)
#

static func MeshInfoTuple(mesh: Mesh, mat: Material, offset := Vector3.ZERO) -> Array:
	return [mesh, mat, offset]

var _class_name: String = '@EntityMeshExtractor'
func _get_class_name() -> String:
	return _class_name
var extractor_name setget , _get_class_name

# Top level node of a scene to process (not 100% on using this yet)
var target: Node
# List of node names able to be processed by extractor definition
var target_node_names: Array # Array<String>

# Main implementation for each resolver's scene form. Effectively a virtual function that
# _must_ be defined by extended class
func resolve_meshes(node: Node = target) -> Array: # Array<Mesh>
	push_error('EntityMeshExtractor.resolve must be overridden.')
	return [ ]
	
func can_target(node: Node) -> bool:
	push_error('EntityMeshExtractor.can_target must be overridden.')
	dprint('EntityMeshExtractor.can_target must be overridden.', 'can_target')
	return false

# Basic helper methods

var SeenChildNodePaths := [ ] # Array<String>
# For storing top level node for debug logging
var AllChildMeshes_top: Node
func AllChildMeshes_FormatPath(node: Node) -> String:
	return '#%s/%s' % [
		AllChildMeshes_top.name,
		AllChildMeshes_top.get_path_to(node)
	]
var AllChildMeshes_base: Spatial
# global_transform of base node
var AllChildMeshes_origin: Vector3
var AllChildMeshes_init_transform: Transform
	
# static func GlobalizeMeshCoord(node: Node, mesh: Mesh) -> Mesh:
	# var mt = MeshDataTool.new()

# Recursively collect all child meshes and store in array. Will also check if base node
# is MeshInstance.
#
# I realized as I was writing this that visibility is not a base Node member, but on Spatial-
# for now stop recursion if node given is not a Spatial, and later consider migrating all the
# typing for processing these nodes to Spatial.
# @NOTE: Need to figure out how to properly collect/transfer transform information to 
#        `process_mesh` later on in ObjExport-atm adding a node name whitelist to work around
#        issues with the player entity's glasses not coming out right (if node_name_whitelist
#        is empty it will be passed as null to helper function, and then ignored).
func AllChildMeshes(base_node: Spatial, meshes: Array, only_visible: bool = true, node_name_whitelist := [ ]):
	# Initialize state
	SeenChildNodePaths = [ ]
	AllChildMeshes_base = base_node
	AllChildMeshes_init_transform = base_node.global_transform
	AllChildMeshes_origin = AllChildMeshes_init_transform.origin
	AllChildMeshes_top = base_node.get_tree().edited_scene_root
	_AllChildMeshes(base_node, meshes, null if node_name_whitelist.size() == 0 else node_name_whitelist, only_visible)

func _AllChildMeshes(node: Node, meshes: Array, node_name_whitelist, only_visible: bool = true):
	if not (node is Spatial):
		# Add a debug message for now
		dprint('Recursed node does not inherit spatial: @%s' % [ AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
		return

	var node_path: String
	var minst: MeshInstance
	if (node is MeshInstance) and \
			(not only_visible or (node as Spatial).visible) and \
			(typeof(node_name_whitelist) != TYPE_ARRAY or node_name_whitelist.has(node.name)):
		minst = node # Just for LSP, unnecessary
		node_path = minst.get_path()
		
		if SeenChildNodePaths.has(node_path):
			dprint("MeshInstance's mesh already already added: @%s" % [ AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
		else:
			# Check for override
			var override = minst.get_active_material(0)
			
			dprint('Recording mesh at global pos %s' % [ minst.global_transform.origin ], '#AllChildMeshes')
			
			# Originaly handled overrides differently, just keeping the if blocks for logging now
			if is_instance_valid(override):
				dprint("Pushing mesh info with override from node: @%s" % [AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
			else:
				dprint("Pushing mesh info from node: @%s" % [AllChildMeshes_FormatPath(node) ], '#AllChildMeshes')
				
			meshes.push_back(MeshInfoTuple(node.mesh, override, minst.global_transform.origin - AllChildMeshes_origin))
			SeenChildNodePaths.push_back(node_path)

	if node.get_child_count() == 0: return

	for child in node.get_children():
		_AllChildMeshes(child, meshes, node_name_whitelist, only_visible)
