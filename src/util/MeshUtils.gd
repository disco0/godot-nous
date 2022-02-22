tool
class_name MeshUtils

#
# Moved and expanded from original function in ObjExport
#

const MESH_UV_TRANSFORM := Vector2(1.0, -1.0)
const MESH_UV_TRANSFORM_OFFSET := Vector2(0.0, 1.0)

# Processes mesh and returns updated mesh. Previously directly manipulated the mesh, but now returns
# updated mesh due to handle extended processing (for now)
static func ProcessMesh(mesh: Mesh, offset: Vector3, scale_factor: float, flip_uv := true) -> ArrayMesh:
	print('[ProcessMesh] Processing mesh %s' % [ mesh ])
	# Handle CSG meshes
	if mesh is PrimitiveMesh:
		print('[ProcessMesh] Converting mesh of type %s to ArrayMesh' % [ mesh.get_class() ])
		mesh = PrimativeToArrayMesh(mesh)

	var mdt := MeshDataTool.new()
	var processed := ArrayMesh.new()

	#region Original single-surface version
	# Will only work with 1 surface for now
	#mdt.create_from_surface(mesh, 0)
	# Remove original mesh
	#mesh.surface_remove(0)
	#mdt.commit_to_surface(mesh)
	#endregion Original single-surface version

	# Iterate through surfaces adding/transforming/appending to new processed one at a time
	var surf_count := mesh.get_surface_count()
	for surf_idx in surf_count:
		print('[ProcessMesh] Surface %d/%d' % [ surf_idx, surf_count ])
		var surface = mesh.surface_get_arrays(surf_idx)
		mdt.create_from_surface(mesh, surf_idx)

		# Step through every vertex of the surface
		for i in range(mdt.get_vertex_count()):
			# Multiply position and normal by scale to apply scaling
			mdt.set_vertex(i, (mdt.get_vertex(i) + offset) / scale_factor)
			mdt.set_vertex_normal(i, mdt.get_vertex_normal(i) / scale_factor)
			# Was required for proper texture mapping initial Player obj generation
			if flip_uv:
				mdt.set_vertex_uv(i, (mdt.get_vertex_uv(i) * MESH_UV_TRANSFORM) + MESH_UV_TRANSFORM_OFFSET)

		# Commit and clear transformed
		mdt.commit_to_surface(processed)
		mdt.clear()

	print('Processed mesh created with %d surfaces.' % [ processed.get_surface_count() ])
	return processed

#	(mesh as ArrayMesh).clear_surfaces()
#	for surf_idx in processed.get_surface_count():
#		(mesh as ArrayMesh).add_surface_from_arrays



static func IndexSurface(mesh: ArrayMesh, surface_index: int) -> void:
	return

	var st := SurfaceTool.new()
	st.create_from(mesh, surface_index)
	st.index()
	var surface = st.commit().surface_get_arrays(0)

	if surface[ArrayMesh.ARRAY_INDEX] == null:
		CSquadUtil.dprint_for('MeshUtils').error(
			#"Failed to convert non-indexed surface to indexed for object %s, mesh %s, surface #%d" % [
			"Failed to convert non-indexed surface to indexed for mesh %s, surface #%d" % [
					#object_name,
					mesh.get_name(),
					surface_index,
				], '#IndexSurface')

static func PrimativeToArrayMesh(csg: PrimitiveMesh) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, csg.get_mesh_arrays())

	return arr_mesh


# Wrapper due to cyclic depenency
static func MeshInfoTuple(mesh: Mesh, mat: Material, offset := Vector3.ZERO) -> Array:
	return MeshInfo.Tuple(mesh, mat, offset)


# Wrapper for ChildMeshSearch
static func CollectChildMeshes(base_node: Spatial, meshes: Array, only_visible: bool = true, node_name_whitelist := [ ]):
	var searcher := ChildMeshSearch.new(base_node, only_visible, node_name_whitelist)
	searcher.search(meshes)


class ChildMeshSearch:

	# Reimplementation of original search function inside EntityChildExtractor.

	var dprint := preload('./logger.gd').Builder.get_for(self)

	var _seen_node_paths := [ ] # Array<String>
	var base: Spatial
	# For storing top level node for debug logging
	var top_node: Node
	# global_transform of base node
	var _base_origin: Vector3
	var _base_transform: Transform
	var _whitelist: Array
	var in_tree := false

	func _init(base_node: Spatial, only_visible: bool = true, node_name_whitelist := [ ]):
		_seen_node_paths = [ ]
		base = base_node
		in_tree = base_node.is_inside_tree()
		_base_transform = base_node.global_transform if in_tree else base_node.transform
		_base_origin = _base_transform.origin
		top_node = base_node # base_node.get_tree().edited_scene_root if in_tree else base_node
		if node_name_whitelist.size() > 0:
			_whitelist = node_name_whitelist
		pass

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
	func search(meshes: Array, node_name_whitelist = null, only_visible := true):
		CollectChildren(base,
				meshes,
				node_name_whitelist if typeof(node_name_whitelist) == TYPE_ARRAY else _whitelist,
				only_visible)


	func format_path(node: Node) -> String:
		if in_tree:
			return "<OUT OF TREE>"
		return '#%s/%s' % [
			top_node.name,
			top_node.get_path_to(node)
		]


	func _mark_seen(node: Node):
		if not base.is_inside_tree():
			return


	func _is_seen(node: Node) -> bool:
		if not base.is_inside_tree():
			return false
		else:
			return _seen_node_paths.has(node.get_path())


	func CollectChildren(node: Node, meshes: Array, node_name_whitelist, only_visible: bool = true):
		if not (node is Spatial):
			if in_tree:
				# Add a debug message for now
				dprint.write('Recursed node does not inherit spatial: @%s' % [ format_path(node) ], '#search')
			return

		var minst: MeshInstance
		if (node is MeshInstance) \
				and (not only_visible or (node as Spatial).visible) \
				and (typeof(node_name_whitelist) != TYPE_ARRAY
						or node_name_whitelist.has(node.get_name())):
			minst = node # Just for LSP, unnecessary

			if _is_seen(minst):
				dprint.write("MeshInstance's mesh already already added: @%s" % [ format_path(node) ], '#search')
			else:
				# Check for override
				var override = minst.get_active_material(0)

				meshes.push_back(MeshInfo.Tuple(
						node.mesh,
						override,
						(minst.global_transform.origin - _base_origin)
							if in_tree
							else minst.transform.origin))

				_mark_seen(minst)

		if node.get_child_count() == 0: return

		for child in node.get_children():
			CollectChildren(child, meshes, node_name_whitelist, only_visible)
