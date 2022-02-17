class_name ObjExporter
extends Node
tool

var dprint := CSquadUtil.dprint_for(self)

static func AssertParentDirExists(obj_path: String) -> bool:
	var dir: Directory = Directory.new()
	var out_dir = obj_path.get_base_dir()
	if not dir.dir_exists(out_dir):
		print('Creating output directory: <%s>' % [ out_dir ])
		var mkdir_err := dir.make_dir_recursive(out_dir)
		if mkdir_err != OK:
			print('  -> Failed with error: %s' % [ mkdir_err ])
			return false

	return true

# Game path set in TrenchBroom preferences
const PROTO_TRENCHBROOM_GAMEFOLDER = 'C:/csquad/project/Maps'

class MaterialPath:
	var regex: RegEx
	func _init():
		regex = RegEx.new()
		regex.compile('[^a-zA-Z_\\d]')

	func normalize_resource_name(name: String) -> String:
		return regex.sub(name, '_', true)

	func mat_export_name_for_obj(mat: Material, obj_name: String, mtl_idx: int = -1) -> String:
		# return '%s_%s_%s.png' % [
		return mat_mtl_basename_for_obj(mat, obj_name) + '.png'

	func mat_mtl_basename_for_obj(mat: Material, obj_name: String, mtl_idx: int = -1) -> String:
		# return '%s_%s_%s.png' % [
		return '%s_%s' % [
				obj_name,
				# mtl_idx,
				normalize_resource_name(mat.resource_name)
			]

var matpath: MaterialPath = MaterialPath.new()


func resolve_spatialmat_albedo(mat: SpatialMaterial) -> Image:
	dprint.write(' -> SpatialMaterial', 'resolve_spatialmat_albedo')
	# Save albedo tex if found
	var alb = mat.get_texture(SpatialMaterial.TEXTURE_ALBEDO)
	if is_instance_valid(alb):
		dprint.write('    -> Found albedo texture in base pass', 'resolve_spatialmat_albedo')
		return alb.get_data()
	else:
		dprint.write('    SpatialMaterial has no albedo texture', 'resolve_spatialmat_albedo')

	# Check for shader albedo texture
	var color = mat.albedo_color
	if is_instance_valid(color):
		dprint.write('    -> Found albedo color in base pass', 'resolve_spatialmat_albedo')
		return image_from_color(color)
	else:
		dprint.write('    SpatialMaterial has no albedo color', 'resolve_spatialmat_albedo')

	dprint.write('    Failed to resolve albedo for SpatialMaterial', 'resolve_spatialmat_albedo')
	return null

func image_from_color(color: Color, width := 128, height := 129) -> Image:
	var image = Image.new()
	image.create(128, 128, false, Image.FORMAT_BPTC_RGBA)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, color)
	return image

func resolve_shadermat_albedo(mat: ShaderMaterial) -> Image:
	dprint.write(' -> ShaderMaterial', 'resolve_shadermat_albedo')
	# Save albedo tex if found
	var alb = mat.get_shader_param('albedoTex')
	if is_instance_valid(alb):
		dprint.write('    -> Found albedo texture shader uniform in base pass', 'resolve_shadermat_albedo')
		return alb.get_data()
	else:
		dprint.write('    SpatialMaterial has no albedo texture shader uniform', 'resolve_shadermat_albedo')

	# Check for shader albedo texture
	var color = mat.get_shader_param('albedo')
	if is_instance_valid(color):
		dprint.write('    -> Found albedo color shader uniform in base pass', 'resolve_shadermat_albedo')
		return image_from_color(color)
	else:
		dprint.write('    SpatialMaterial has no albedo color shader uniform', 'resolve_shadermat_albedo')

	dprint.write('    Failed to resolve albedo for ShaderMaterial', 'resolve_shadermat_albedo')
	return null

# Search for an albedo in common places, and return it if found/generated
func resolve_mat_albedo(mat: Material) -> Image:
	var resolved := false
	var img: Image
	dprint.write('Entering Material Checks', 'resolve_mat_albedo')
	if mat is SpatialMaterial:
		img = resolve_spatialmat_albedo(mat)
		resolved = true

	elif mat is ShaderMaterial:
		img = resolve_shadermat_albedo(mat)
		resolved = true

	if resolved:
		return img
	else:
		dprint.write(' -> Default', 'resolve_mat_albedo')
		dprint.write('    (Fallback solid color not implemented)', 'resolve_mat_albedo')
		return null


# (mtl_idx currently not used)
func save_material_png(mat: Material, obj_name: String, mat_path: String = "") -> int:
	if mat_path == "":
		# Save to textures subfolder in obj file directory
		mat_path = CSquadUtil.Settings.tb_game_folder.models_tex_dir.plus_file(
				matpath.mat_export_name_for_obj(mat, obj_name))
		dprint.write('mat_path not passed, computed path: <%s>' % [ mat_path ], 'save_material_png')
	else:
		dprint.write('Saving to passed mat_path: <%s>' % [ mat_path ], 'save_material_png')


	if not AssertParentDirExists(mat_path):
		dprint.write('Failed to create output directory <%s>' % [ mat_path ], 'save_material_png')
		return ERR_CANT_CREATE

	var img : Image = resolve_mat_albedo(mat)
	if is_instance_valid(img):
		dprint.write('Writing material png to <%s>' % [ mat_path ], 'save_material_png')

		return img.save_png(mat_path)

	else:
		push_warning('Failed to resolve an albedo image for material <%s>' % [ mat.resource_path ])
		return ERR_CANT_RESOLVE

	return ERR_CANT_CREATE

# type MtlPathMatResourcePathTuple = Tuple[ExportedPNGMtlPath: string, MaterialResPath: string]
# Array<MtlPathMatResourcePathTuple>
# @FIXME: Why the fuck did I not do a dictionary lol
var mtlpath_matres_paths := [ ]

# Returns index of array item with matching MtlPathMatResourcePathTuple value,
# or -1 if no match
func mtlpath_matres_match_by_mtlpath(mtlpath: String) -> int:
	for i in mtlpath_matres_paths.size():
		if mtlpath == mtlpath_matres_paths[i][0]:
			return i
	return -1

# Returns index of array item with matching MtlPathMatResourcePathTuple value,
# or -1 if no match
func mtlpath_matres_match_by_respath(res_path: String) -> int:
	for i in mtlpath_matres_paths.size():
		if res_path == mtlpath_matres_paths[i][1]:
			return i
	return -1

# Returns true if
#  - No existing MtlPathMatResourcePathTuple set to mtlpath arg
#  - Existing MtlPathMatResourcePathTuple value equal to mtlpath
#      && mat_resource_path equals the matched MtlPathMatResourcePathTuple's paired MaterialResPath
func check_conflict_mtlpath(mtlpath: String, mat_resource_path: String) -> bool:
	# Search for matching mtlpath in existing entries
	var match_idx := mtlpath_matres_match_by_mtlpath(mtlpath)
	# No valid index, no conflict
	if match_idx == -1:
		return false

	# Conflict if resolved index's MaterialResPath value does not mat_resource_path
	return mat_resource_path != mtlpath_matres_paths[match_idx][1]

func commit_mtlpath(mtlpath: String, mat_resource_path: String) -> void:
	if check_conflict_mtlpath(mtlpath, mat_resource_path):
		push_error("Can't push new mtlpath/resource path relation, conflict detected.")
		return
	mtlpath_matres_paths.push_front([mtlpath, mat_resource_path])

# Checks that default computed name is not already used, or is already used with the exact same
# texture.
func get_safe_mat_export_name_for_obj(mat: Material, object_name: String) -> String:
	# (Should've done this before the conflict check)
	# Check if resource is already a MaterialResPath tuple value
	var respath_match_idx = mtlpath_matres_match_by_respath(mat.resource_path)
	if respath_match_idx > 0:
		var mtlpath = mtlpath_matres_paths[respath_match_idx][0]
		dprint.write('Found existing mtlpath <%s> for material resource path <%s>' % [
					mtlpath, mat.resource_path
				], 'get_safe_mat_export_name_for_obj')
		return mtlpath

	var mtlpath = matpath.mat_mtl_basename_for_obj(mat, object_name)

	# If no conflict, return it
	if not check_conflict_mtlpath(mtlpath, mat.resource_path):
		dprint.write('<%s> defined with matching resource path, or not yet used.' % [ mtlpath ], 'get_safe_mat_export_name_for_obj')
		return mtlpath

	# Else begin incrementing on end until save name
	dprint.write('Found existing texture resource registered under %s, iterating number prefixes until new one found' % [
				mtlpath], 'get_safe_mat_export_name_for_obj')
	var new_name = mtlpath
	var inc = 1
	while true:
		new_name = '%s_%d' % [ object_name, inc ]
		dprint.write(' -> %s' % [ new_name ], 'get_safe_mat_export_name_for_obj')
		if not check_conflict_mtlpath(new_name, mat.resource_path):
			dprint.write('   => %s' % [ new_name ], 'get_safe_mat_export_name_for_obj')
			return new_name

	return "ok"

const DATA_FMT := {
	OBJ   = "o %s\n",
	VERT  = "v %s %s %s\n",
	UV    = "vt %s %s\n",
	NORM  = "vn %s %s %s\n",
	GROUP = "g surface%s\n",
	MAT   = "usemtl %s\n",
	MTL_LIB = "mtllib %s\n"
}

var MESHINFO = ObjBuilder.MESHINFO

# @NOTE: Current implementation of obj loading in TrenchBroom does not use standard mtl
#        implementation-textures are loaded via `usemtl <img-path>`, where `<img-path>` is a
#        relative path from base of games folder.
# @NOTE: Originally passed an array of meshes, but to handle things like offsets/overrides its now
#        an array of arrays containing contents at indicies reflected by the MESHINFO enum.
func save_meshes_to_obj(meshes: Array, object_name: String, obj_path: String = ""):
	if obj_path == "":
		obj_path = CSquadUtil.Settings.tb_game_folder.models_dir.plus_file(object_name + ".obj")

	if not AssertParentDirExists(obj_path):
		dprint.write('Failed to create output directory, exiting early.', 'save_meshes_to_obj')
		return

	if typeof(meshes) == TYPE_ARRAY and meshes.size() > 0:
		dprint.write('Building object from %s meshes' % [ meshes.size() ], 'save_meshes_to_obj')
	else:
		push_error('meshes argument is invalid or empty array.')
		return

	# Fallback material
	# If any material is going to get checked for an existing saved image on disk, its this
	var mat_fallback := SpatialMaterial.new()
	mat_fallback.resource_name = "BlankMaterial"

	# Object definition
	var output := ''
	# Mat definition
	var mat_output := ''

	# Write all surfaces in mesh (obj file indices start from 1)
	var index_base:      int = 1
	var mesh:            Mesh
	var mesh_surf_count: int
	var mesh_idx:        int = -1
	var mesh_count:      int = meshes.size()
	var mat:             Material
	var mat_mtlpath:     String
	var prefix:          String
	var offset:          Vector3 = Vector3.ZERO

	# Seems like this should go before def
	# output += DATA_FMT.MTL_LIB % [ mtllib_path ]

	# Declare obj
	output += DATA_FMT.OBJ % [ object_name ]

	var mat_override := false
	var mat_override_mtlpath: String
	for mesh_item in meshes:
		mesh_idx += 1
		prefix = '[%02d/%02d]' % [ mesh_idx + 1, mesh_count ]
		dprint.write(' - %s Processing Mesh'   % [ prefix ], 'save_meshes_to_obj')

		# If extended data tuple
		if typeof(mesh_item) == TYPE_ARRAY:
			# Should always have mesh in first element1
			mesh = mesh_item[MESHINFO.MESH].duplicate() as Mesh

			# Check for override
			if mesh_item[MESHINFO.OVERRIDE] is Material:
				mat_override = true
				dprint.write('Handling override tuple.', 'save_meshes_to_obj')
				mat  = mesh_item[MESHINFO.OVERRIDE]

				mat_override_mtlpath = get_safe_mat_export_name_for_obj(mat, object_name)
				dprint.write('Saving override material with mtlpath <%s>' % [ mat_override_mtlpath ], 'save_meshes_to_obj')
				save_material_png(mat, object_name,
						CSquadUtil.Settings.tb_game_folder.usemtl_to_global(mat_override_mtlpath)+'.png')
				commit_mtlpath(mat_override_mtlpath, mat.resource_path)
			# Also handle no override here now that mesh info array has other stuff
			else:
				mat = null
				mat_mtlpath = ''
				mat_override = false

			# Check for offset
			if mesh_item[MESHINFO.OFFSET] is Vector3:
				offset = mesh_item[MESHINFO.OFFSET]
			else:
				# Just in case for now
				offset = Vector3.ZERO

		# Legacy meshes array content, keep handling for now
		else:
			assert(mesh_item is Mesh)
			mesh = mesh_item.duplicate() as Mesh
			mat  = null
			mat_mtlpath = ''
			mat_override = false

		mesh_surf_count = mesh.get_surface_count()
		dprint.write('   %s Surface Count: %s' % [ prefix, mesh_surf_count ], 'save_meshes_to_obj')

		# Info comment
		output += '# Mesh %s\n' % [ prefix.substr(1, 5) ]
		DATA_FMT.OBJ % [ "%s_%s" % [ object_name, mesh_idx] ]

		var vert_count: int
		for s in range(mesh_surf_count):
			var surface = mesh.surface_get_arrays(s)
			if surface[ArrayMesh.ARRAY_INDEX] == null:
				push_warning("Saving only supports indexed meshes for now, skipping non-indexed surface " + str(s))
				continue

			vert_count = surface[ArrayMesh.ARRAY_INDEX].size()
			dprint.write('   %s Vert Count:    %s' % [ prefix, vert_count ], 'save_meshes_to_obj')

			output += DATA_FMT.GROUP % [ 'mesh-' + str(s) ]
			#output += "g surface" + str(s) + "\n"

			# Use override if set
			if mat_override:
				mat_mtlpath = mat_override_mtlpath
			else:
				mat = mesh.surface_get_material(s)
				mat_mtlpath = get_safe_mat_export_name_for_obj(mat, object_name)

				dprint.write('   %s Saving material for %s' % [ prefix, mat_mtlpath ], 'save_meshes_to_obj')
				save_material_png(mat, object_name,
					CSquadUtil.Settings.tb_game_folder.usemtl_to_global(mat_mtlpath + '.png'))
				commit_mtlpath(mat_mtlpath, mat.resource_path)

			if mat == null:
				dprint.write('   %s Using fallback material' % [ prefix ], 'save_meshes_to_obj')
				mat = mat_fallback

			dprint.write('   %s Material: %s' % [
					prefix,
					("<Override:%s>" if mat_override else "%s") % mat_mtlpath ], 'save_meshes_to_obj')

			if len(mat_mtlpath) > 0:
				output += DATA_FMT.MAT % [ CSquadUtil.Settings.tb_game_folder.usemtl_path(mat_mtlpath) ]
			else:
				push_warning('Reached usemtl expression with empty mat_mtlpath')

			for v in surface[ArrayMesh.ARRAY_VERTEX]:
				output += DATA_FMT.VERT % [ str(v.x), str(v.y), str(v.z) ]
				#output += "v " + str(v.x) + " " + str(v.y) + " " + str(v.z) + "\n"

			var has_uv = false
			if surface[ArrayMesh.ARRAY_TEX_UV] != null:
				for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
					output += DATA_FMT.UV % [ str(uv.x), str(uv.y) ]
					#output += "vt " + str(uv.x) + " " + str(uv.y) + "\n"
				has_uv = true

			var has_n = false
			if surface[ArrayMesh.ARRAY_NORMAL] != null:
				for n in surface[ArrayMesh.ARRAY_NORMAL]:
					output += DATA_FMT.NORM % [ str(n.x), str(n.y), str(n.z) ]
					#output += "vn " + str(n.x) + " " + str(n.y) + " " + str(n.z) + "\n"
				has_n = true

			# Write triangle faces
			# Note: Godot's front face winding order is different from obj file format
			var i = 0
			var indices = surface[ArrayMesh.ARRAY_INDEX]
			while i < indices.size():

				output += "f " + str(index_base + indices[i])
				if has_uv:
					output += "/" + str(index_base + indices[i])
				if has_n:
					if not has_uv:
						output += "/"
					output += "/" + str(index_base + indices[i])

				output += " " + str(index_base + indices[i + 2])
				if has_uv:
					output += "/" + str(index_base + indices[i + 2])
				if has_n:
					if not has_uv:
						output += "/"
					output += "/" + str(index_base + indices[i + 2])

				output += " " + str(index_base + indices[i + 1])
				if has_uv:
					output += "/" + str(index_base + indices[i + 1])
				if has_n:
					if not has_uv:
						output += "/"
					output += "/" + str(index_base + indices[i + 1])

				output += "\n"

				i += 3

			index_base += surface[ArrayMesh.ARRAY_VERTEX].size()

			#mat_output += "# Material %s\n" % [ str(mat.resource_name) ]
			#mat_output += "newmtl %s\n" % [ str(mat.resource_name) ]
			#mat_output += "Kd %s %s %s\n" % [ mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b ]
			#mat_output += "Ke %s %s %s\n" % [ mat.emission.r, mat.emission.g, mat.emission.b ]
			#mat_output += "d %s\n" % [ mat.albedo_color.a ]

	dprint.write('Processed all meshes.', 'save_meshes_to_obj')

	write_file(obj_path, output)

	dprint.write('Export complete.', 'save_meshes_to_obj')

# (Assumes path is valid)
func write_file(path: String, content: String) -> int:
	var file: File = File.new()

	dprint.write('Opening file path for output: <%s>' % [ path ], 'write_file')

	var open_err := file.open(path, File.WRITE)
	if open_err != OK:
		push_warning('Error code %s opening output file <%s>' % [ open_err, path ])
		file.close()
		dprint.write('[WARNING] Failed to open output file <%s>, error code %s' % [ path, open_err  ], 'write_file')
		return open_err

	dprint.write('Saving constructed %s to <%s>' % [ path.get_extension(), path.get_extension() ], 'write_file')
	file.store_string(content)
	file.close()

	return OK


# Dump given mesh to obj file
func save_mesh_to_obj(mesh: Mesh, obj_path: String, object_name: String):
	save_meshes_to_obj([mesh], obj_path, object_name)

# Original, saved for posterity
func _orig_save_mesh_to_obj(var mesh: Mesh, var obj_path: String, var object_name: String):
	# Object definition
	var output = "o " + object_name + "\n"

	# Write all surfaces in mesh (obj file indices start from 1)
	var index_base = 1
	for s in range(mesh.get_surface_count()):

		var surface = mesh.surface_get_arrays(s)
		if surface[ArrayMesh.ARRAY_INDEX] == null:
			push_warning("Saving only supports indexed meshes for now, skipping non-indexed surface " + str(s))
			continue

		output += "g surface" + str(s) + "\n"

		for v in surface[ArrayMesh.ARRAY_VERTEX]:
			output += "v " + str(v.x) + " " + str(v.y) + " " + str(v.z) + "\n"

		var has_uv = false
		if surface[ArrayMesh.ARRAY_TEX_UV] != null:
			for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
				output += "vt " + str(uv.x) + " " + str(uv.y) + "\n"
			has_uv = true

		var has_n = false
		if surface[ArrayMesh.ARRAY_NORMAL] != null:
			for n in surface[ArrayMesh.ARRAY_NORMAL]:
				output += "vn " + str(n.x) + " " + str(n.y) + " " + str(n.z) + "\n"
			has_n = true

		# Write triangle faces
		# Note: Godot's front face winding order is different from obj file format
		var i = 0
		var indices = surface[ArrayMesh.ARRAY_INDEX]
		while i < indices.size():

			output += "f " + str(index_base + indices[i])
			if has_uv:
				output += "/" + str(index_base + indices[i])
			if has_n:
				if not has_uv:
					output += "/"
				output += "/" + str(index_base + indices[i])

			output += " " + str(index_base + indices[i + 2])
			if has_uv:
				output += "/" + str(index_base + indices[i + 2])
			if has_n:
				if not has_uv:
					output += "/"
				output += "/" + str(index_base + indices[i + 2])

			output += " " + str(index_base + indices[i + 1])
			if has_uv:
				output += "/" + str(index_base + indices[i + 1])
			if has_n:
				if not has_uv:
					output += "/"
				output += "/" + str(index_base + indices[i + 1])

			output += "\n"

			i += 3

		index_base += surface[ArrayMesh.ARRAY_VERTEX].size()

	var file = File.new()
	file.open(obj_path, File.WRITE)
	file.store_string(output)
	file.close()

