tool
class_name MeshUtils
#
# Moved and expanded from original function in ObjExport
#

# Blacklisted node groups
const MESHINSTANCE_GROUP_BLACKLIST_BASE := 'obj-no-export'
const MESHINSTANCE_GROUP_BLACKLIST := [
	MESHINSTANCE_GROUP_BLACKLIST_BASE
]
const MESH_UV_TRANSFORM := Vector2(1.0, -1.0)
const MESH_UV_TRANSFORM_OFFSET := Vector2(0.0, 1.0)


# @NOTE: AABB.get_center not in stable atm
#
# https://docs.godotengine.org/en/latest/classes/class_aabb.html#class-aabb-method-get-center
# Returns the center of the AABB, which is equal to position + (size / 2).
static func GetAABBCenter(aabb: AABB) -> Vector3:
	return aabb.position + (aabb.size / 2)


static func ApplyAABBToMesh(mesh: Mesh, aabb: AABB, inverse_scale_factor: float) -> ArrayMesh:
	var mdt := MeshDataTool.new()
	var processed := ArrayMesh.new()
	#var offset: Vector3 = -1.0 * aabb.get_center() * inverse_scale_factor
	var offset: Vector3 = -1.0 * GetAABBCenter(aabb) * inverse_scale_factor

	# Iterate through surfaces adding/transforming/appending to new processed one at a time
	var surf_count := mesh.get_surface_count()
	for surf_idx in surf_count:
		#print('[ProcessMesh] Surface %d/%d' % [ surf_idx + 1, surf_count ])
		var surface = mesh.surface_get_arrays(surf_idx)
		mdt.create_from_surface(mesh, surf_idx)

		# Step through every vertex of the surface
		for i in range(mdt.get_vertex_count()):
			var vert := mdt.get_vertex(i)
			# @NOTE: Need to figure out the correct order of operations here, I forgot about the
			#        inverse scale factor application
			mdt.set_vertex(i, vert + offset)
			mdt.set_vertex_normal(i, vert + offset)

		# Commit and clear transformed
		mdt.commit_to_surface(processed)
		mdt.clear()

	#print('Processed mesh created with %d surfaces.' % [ processed.get_surface_count() ])
	return processed


# Processes mesh and returns updated mesh. Previously directly manipulated the mesh, but now returns
# updated mesh due to handle extended processing (for now)
static func ProcessMesh(mesh: Mesh, modifier, inverse_scale_factor: float, flip_uv := true, aabb_norm := EntityMeshExtractor.AABB_NORMALIZATION_ENABLED) -> ArrayMesh:
	print('[ProcessMesh] Processing mesh %s' % [ mesh ])

	# Handle CSG meshes
	if mesh is PrimitiveMesh:
		#print('[ProcessMesh] Converting mesh of type %s to ArrayMesh' % [ mesh.get_class() ])
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

	var offset: Vector3 = Vector3.ZERO
	var is_transform := false
	if modifier is Transform:
		is_transform = true
	else:
		offset = modifier as Vector3

	var scale: Vector3 = Vector3.ONE

	# Iterate through surfaces adding/transforming/appending to new processed one at a time
	var surf_count := mesh.get_surface_count()
	for surf_idx in surf_count:
		#print('[ProcessMesh] Surface %d/%d' % [ surf_idx + 1, surf_count ])
		var surface = mesh.surface_get_arrays(surf_idx)
		mdt.create_from_surface(mesh, surf_idx)

		# Step through every vertex of the surface
		for i in range(mdt.get_vertex_count()):
			var vert := mdt.get_vertex(i)
			if is_transform:
				vert = (modifier as Transform).xform(vert)
			else:
				# Old origin offset only modifier
				vert = (vert + modifier)

			mdt.set_vertex(i, (vert * scale) / inverse_scale_factor)
			mdt.set_vertex_normal(i, mdt.get_vertex_normal(i) / inverse_scale_factor)

			# Required for proper texture mapping (not sure why yet)
			if flip_uv:
				mdt.set_vertex_uv(i, (mdt.get_vertex_uv(i) * MESH_UV_TRANSFORM) + MESH_UV_TRANSFORM_OFFSET)

		# Commit and clear transformed
		mdt.commit_to_surface(processed)
		mdt.clear()

	#print('Processed mesh created with %d surfaces.' % [ processed.get_surface_count() ])
	return processed


static func IndexSurface(mesh: ArrayMesh, surface_index: int) -> void:
	return
	var st := SurfaceTool.new()
	st.create_from(mesh, surface_index)
	st.index()
	var surface = st.commit().surface_get_arrays(0)

	if surface[ArrayMesh.ARRAY_INDEX] == null:
		Nous.dprint_for('MeshUtils').error(
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
static func MeshInfoTuple(mesh: Mesh, mat: Material, offset) -> Array:
	return MeshInfo.TransformTuple(mesh, mat, offset)


# Wrapper for ChildMeshSearch
static func CollectChildMeshes(base_node: Spatial, meshes: Array, only_visible: bool = true, node_name_whitelist := [ ]):
	var searcher := ChildMeshSearch.new(base_node, only_visible, node_name_whitelist)
	searcher.search(meshes)
	# debugging
	return meshes


class ChildMeshSearch:
	var dprint = preload('./logger.gd').Builder.get_for(self)

	var group_blacklist := MESHINSTANCE_GROUP_BLACKLIST.duplicate()
	# Blacklist matches will stop recursive search when enabled
	var group_blacklist_nested := false
	# Fully enable/disable group blacklisting (set to false if blacklist is empty)
	var group_blacklist_enabled := true
	var _seen_node_paths := [ ] # Array<String>
	var base: Spatial
	# For storing top level node for debug logging
	var top_node: Node
	var _base_transform: Transform
	var _whitelist: Array
	var in_tree := false


	func _init(base_node: Spatial, only_visible: bool = true, node_name_whitelist := [ ]):
		_seen_node_paths = [ ]

		in_tree = base_node.is_inside_tree()
		base = base_node
		_base_transform = base_node.global_transform if in_tree else base_node.transform
		top_node = base_node
		if node_name_whitelist.size() > 0:
			_whitelist = node_name_whitelist


	func search(meshes: Array, node_name_whitelist = null, only_visible := true):
		# Check for empty blacklist and disable blacklisting entirely if empty
		if group_blacklist.size() == 0:
			group_blacklist_enabled = false

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


	func CollectChildren(node: Node, meshes: Array, node_name_whitelist = null, only_visible: bool = true, depth: int = 0):
		var indent := '  '.repeat(depth)
		if not (node as Spatial):
			if in_tree:
				dprint.write('%sRecursed node does not inherit spatial: @%s' % [ indent, format_path(node) ], '#CollectChildren')
			else:
				dprint.write('%sNode does not inherit spatial @%s' % [ indent, node ], '#CollectChildren')
			return

		var blacklisted := has_blacklisted_group(node)
		# Exit out early iff blacklisted and nested blacklisting enabled
		if blacklisted and group_blacklist_nested:
			return

		var minst: MeshInstance
		if not blacklisted \
				and (node is MeshInstance) \
				and (not only_visible or node.visible) \
				and (typeof(node_name_whitelist) != TYPE_ARRAY
						or node_name_whitelist.size() == 0
						or node_name_whitelist.has(node.get_name())):

			minst = node # Just for LSP, unnecessary

			if _is_seen(minst):
				dprint.write("MeshInstance's mesh already already added: @%s" % [ format_path(node) ], '#CollectChildren')
			else:
				# Check for override
				var override = minst.get_active_material(0)

				meshes.push_back(MeshInfo.TransformTuple(
						node.mesh,
						override,
						CollectTransform(base, minst, in_tree)))

				_mark_seen(minst)

		if node.get_child_count() == 0: return

		for child in node.get_children():
			#dprint.write('%s- Searching child %s' % [ indent, child.get_name() ], 'CollectChildren')
			CollectChildren(child, meshes, node_name_whitelist, only_visible, depth + 1)


	func has_blacklisted_group(node: Node) -> bool:
		for group in node.get_groups():
			if group in group_blacklist:
				return true
		return false


	static func CollectTransform(base: Spatial, minst: Spatial, in_tree) -> Transform:
		return (
			minst.get_global_transform() if in_tree else
				# It'd be good to somehow cache these results to avoid constant rewalking
				GetRelativeTransform(base, minst)
		)

	# Alternative to get_global_transform that works out of tree and supports arbitrary (parent)
	# nodes. Based on get_global_transform implementation (godot/scene/3d/spatial.cpp:331)
	static func GetRelativeTransform(base: Spatial, child: Spatial) -> Transform:
		if child.is_set_as_toplevel():
			#print('[GetRelativeTransform] Child is already toplevel, returning its transform')
			return child.transform

		var xform: Transform = child.transform

		var current := child.get_parent_spatial()
		var depth := 0

		var base_id := base.get_instance_id()
		var DEBUG_MAX_DEPTH = 100

		while (current):
			if (current.get_instance_id() == base_id):
				break
			if current.is_a_parent_of(base):
				break

			if current is Spatial:
				xform.origin += xform.xform(current.transform.origin)
				xform.basis *= current.transform.basis

			current = current.get_parent_spatial()
			depth += 1
			if depth >= DEBUG_MAX_DEPTH:
				push_error('Reached max depth limit.')
				break

		#print('[GetRelativeTransform] Resolved transform: %s' % [ xform ])
		return xform
