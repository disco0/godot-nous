class_name MeshInfo

static func Tuple(mesh: Mesh, mat: Material, offset := Vector3.ZERO) -> Array:
	return [mesh.duplicate(), mat, offset]
