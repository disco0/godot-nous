tool
class_name MeshUtils

#
# Moved and expanded from original function in ObjExport
#

const MESH_UV_TRANSFORM := Vector2(1.0, -1.0)
const MESH_UV_TRANSFORM_OFFSET := Vector2(0.0, 1.0)

static func ProcessMesh(mesh: Mesh, offset: Vector3, scale_factor: float, flip_uv := true) -> void:
	var mdt = MeshDataTool.new()

	# Handle CSG meshes
	if mesh is PrimitiveMesh:
		mesh = PrimativeToArrayMesh(mesh)

	# Will only work with 1 surface for now
	mdt.create_from_surface(mesh, 0)

	# Step through every vertex of the surface
	for i in range(mdt.get_vertex_count()):
		# Multiply position and normal by scale to apply scaling
		mdt.set_vertex(i, (mdt.get_vertex(i) + offset) / scale_factor)
		mdt.set_vertex_normal(i, mdt.get_vertex_normal(i) / scale_factor)
		# Was required for proper texture mapping initial Player obj generation
		if flip_uv:
			mdt.set_vertex_uv(i, (mdt.get_vertex_uv(i) * MESH_UV_TRANSFORM) + MESH_UV_TRANSFORM_OFFSET)

	# Remove original mesh
	mesh.surface_remove(0)
	mdt.commit_to_surface(mesh)

static func PrimativeToArrayMesh(csg: PrimitiveMesh) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, csg.get_mesh_arrays())

	return arr_mesh
