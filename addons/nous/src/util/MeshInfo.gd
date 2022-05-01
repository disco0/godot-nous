class_name MeshInfo


enum MESHINFO {
	MESH = 0,
	OVERRIDE,
	TRANSFORM,
	# Currently unused
	SCALE_FACTOR,
}


static func Tuple(mesh: Mesh, mat: Material, offset := Vector3.ZERO) -> Array:
	return [mesh.duplicate(), mat, offset]


# @NOTE: Replaces Tuple once transform resolution outside of tree is resolved
static func TransformTuple(mesh: Mesh, mat: Material, transform: Transform) -> Array:
	return [mesh.duplicate(), mat, transform]
