tool
class_name ObjExporter
extends Node

# @TODO: All the actual export related code is fine for now, but in preparation for batch exporting
#        via UI panel the main export function (and any batch wrapper) should be cancellable. First
#        at this will be with godot-dispatch-queue[0]
#
#       [0]: https://github.com/gilzoide/godot-dispatch-queue


# Emits at:
#  - After output folder check, before creating output string
signal export_started(object_name, mesh_count)
# Emits at:
#  - Start of each mesh
#    - surface_idx = -1
#    - vertex_idx = -1
#
#  - Start of each surface
#    - vertex_idx = -1
#
#  - Every MESH_INDEX_PROGRESS_INTERVAL meshes
#
#  - End of meshes
#    - mesh_idx = mesh_count
#    - surface_idx = -1
#    - vertex_idx = -1
# export_progress(mesh_idx: int, surface_idx: int, vertex_progress_pct: float)
signal export_progress(mesh_idx, surface_idx, vertex_idx, curr_surface_vertex_total)
# Emits at:
#  - File save failure
#  - Cancelled
signal export_failed(object_name)
# Emits at:
#  - `cancel` member set true
signal export_cancelled(object_name)
# Emits at:
#  - File save success
#  - File save failure
signal export_completed(object_name)
# Emits at:
#  - File save success
signal export_success(object_name)


const YIELD_METHOD := 'timeout'
const YIELD_DURATION := 0.0
const DEFAULT_MESH_INDEX_PROGRESS_INTERVAL := 100
export (int, 0) var progress_interval := DEFAULT_MESH_INDEX_PROGRESS_INTERVAL
const DATA_FMT := {
	OBJ   = "o %s\n",
	VERT  = "v %f %f %f\n",
	UV    = "vt %f %f\n",
	NORM  = "vn %f %f %f\n",
	GROUP = "g surface%s\n",
	MAT   = "usemtl %s\n",
	MTL_LIB = "mtllib %s\n"
}
const MESHINFO := MeshInfo.MESHINFO


export (bool) var blocking = false


var dprint := CSquadUtil.dprint_for(self)
var matpath: MaterialPath = MaterialPath.new()
var cancelled := false
var tb_game_dir := CSquadUtil.Settings.tb_game_dir
var scene_tree: SceneTree


func _init() -> void:
	if not is_connected("ready", self, '_init_defaults'):
		connect("ready", self, '_init_defaults')


func _init_defaults() -> void:
	tb_game_dir = CSquadUtil.Settings.tb_game_dir
	if is_inside_tree():
		scene_tree = get_tree()
	blocking = false


func set_custom_tb_game_dir(base_path: String):
	tb_game_dir = TrenchBroomGameFolder.new(base_path)


func _emit_progress(mesh_idx: int, surface_idx: int, indec_idx: int, curr_surface_indec_total: int):
	emit_signal("export_progress", mesh_idx, surface_idx, indec_idx, curr_surface_indec_total)
	#dprint.write("Progress: %s %s %s %s" % [ mesh_idx, surface_idx, vertex_idx, vertex_total ])


# Just going to be a dumb pool string array for now
# @NOTE: fuck this is already so much faster lol
class ObjFileData:
	const DATA_FMT := {
		OBJ   = "o %s",
		VERT  = "v %f %f %f",
		UV    = "vt %f %f",
		NORM  = "vn %f %f %f",
		GROUP = "g surface%s",
		MAT   = "usemtl %s",
		MTL_LIB = "mtllib %s"
	}
	const EOL_DEFAULT := '\n'

	func _init():
		pass

	var eol := EOL_DEFAULT
	var lines := PoolStringArray()

	func push(line: String) -> void:
		lines.push_back(line)

	func object(name: String) -> void:
		lines.push_back(DATA_FMT.OBJ % [ name ])

	# TODO: This is enumed under group, but surface is better as its both actually what the
	#       syntax is and implies incrementing the surface index. Going to keep the `group` method
	#       for as a version that doesn't effect the surface state tracking (don't use it tho lol)
	func group(name: String) -> void:
		lines.push_back(DATA_FMT.GROUP % [ name ])

	func surface(name: String) -> void:
		lines.push_back(DATA_FMT.GROUP % [ name ])
		next_surface()

	func material(path: String) -> void:
		lines.push_back(DATA_FMT.MAT % [ path ])

	func vert(vert: Vector3) -> void:
		lines.push_back(DATA_FMT.VERT % [ vert[0], vert[1], vert[2] ])

	func uv(uv: Vector2) -> void:
		lines.push_back(DATA_FMT.UV % [ uv.x, uv.y ])

	func normal(n: Vector3) -> void:
		lines.push_back(DATA_FMT.NORM % [ n.x, n.y, n.z ])

	func comment(body: String) -> void:
		lines.push_back('# ' + body)

	func get_file() -> String:
		return lines.join(eol)

	# Values should be reset after adding declaring new sub-objects, and set true when checking and
	# iterating through their related surface[ArrayMesh.ARRAY_*] arrays (still in main function,
	# not transfered over yet). Having these will allow for building face data in the class while
	# still preserving the building pattern used in the original implmentation.
	#
	# @NOTE: Nevermind, these need to be bool arrays, one value per surface, which also means that
	#        some kind of `add_surface` method to increment will be necessary (or just don't
	#        preserve this information after finishing each one, this will probably cause a bug
	#        later tbh)
	#
	# Following are related implementations
	var surf_has_uv := [ ]
	var surf_has_norm := [ ]
	var current_surface_index: int = -1

	func next_surface() -> void:
		current_surface_index += 1

		surf_has_norm.push_back(false)
		surf_has_uv.push_back(false)
		assert(surf_has_norm.size() - 1 == current_surface_index)

	func process_uv(surface) -> void:
		if typeof(surface[ArrayMesh.ARRAY_TEX_UV]) == TYPE_VECTOR2_ARRAY:
			for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
				self.uv(uv)
			surf_has_uv[current_surface_index] = true
		else:
			surf_has_uv[current_surface_index] = false

	func process_norm(surface) -> void:
		if typeof(surface[ArrayMesh.ARRAY_NORMAL]) == TYPE_VECTOR3_ARRAY:
			for norm in surface[ArrayMesh.ARRAY_NORMAL]:
				self.normal(norm)
			surf_has_norm[current_surface_index] = true
		else:
			surf_has_norm[current_surface_index] = false

	func process_verts(surface) -> void:
		for v in surface[ArrayMesh.ARRAY_VERTEX]:
			self.vert(v)

	func current_surface_has_uv() -> bool:
		return surf_has_uv[current_surface_index]

	func current_surface_has_normal() -> bool:
		return surf_has_norm[current_surface_index]


# Main obj export function. Can be cancelled via
#
# @NOTE: Current implementation of obj loading in TrenchBroom does not use standard mtl
#        implementation-textures are loaded via `usemtl <img-path>`, where `<img-path>` is a
#        relative path from base of games folder.
# @NOTE: Originally passed an array of meshes, but to handle things like offsets/overrides its now
#        an array of arrays containing contents at indicies reflected by the MESHINFO enum.
func save_meshes_to_obj(meshes: Array, object_name: String, obj_path: String = "", separate_objects := false):
	if not is_instance_valid(tb_game_dir):
		dprint.error('tb_game_dir member not initalized, cancelling export process', 'save_meshes_to_obj')
		emit_signal("export_cancelled", object_name)
		return

	var custom_obj_path := not obj_path.empty()
	if not custom_obj_path:
		obj_path = tb_game_dir.models_dir.plus_file(object_name + ".obj")
		dprint.write('Using configured models path: %s' % [ obj_path], 'save_meshes_to_obj')
	else:
		dprint.write('Using custom output path: %s' % [ obj_path ], 'save_meshes_to_obj')
		# (If not explicitly passed,) append models subfolder to emulate current game folder
		# structure: <BASE>/models/<EXPORTED>/../..

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

	var obj := ObjFileData.new()

	# Write all surfaces in mesh (obj file indices start from 1)
	var index_base:      int = 1
	var mesh:            Mesh
	var mesh_surf_count: int
	var mesh_idx:        int = -1
	var mesh_count:      int = meshes.size()
	var mat:             Material
	var mat_override:    bool = false
	var mat_mtlpath:     String
	var mat_override_mtlpath: String
	var prefix:          String
	var offset:          Vector3 = Vector3.ZERO
	# Used to track total over multiple surfaces
	var indicies_commit := 0

	emit_signal("export_started", object_name, mesh_count)

	if not separate_objects:
		obj.object(object_name)

	for mesh_item in meshes:
		mesh_idx += 1

		prefix = '[%02d/%02d]' % [ mesh_idx + 1, mesh_count ]

		assert(typeof(mesh_item) == TYPE_ARRAY)

		# Should always have mesh in first element
		mesh = mesh_item[MESHINFO.MESH] as Mesh

		# Check for override
		if mesh_item[MESHINFO.OVERRIDE] is Material:
			mat_override = true
			#dprint.write('Handling override tuple.', 'save_meshes_to_obj')
			mat  = mesh_item[MESHINFO.OVERRIDE]

			mat_override_mtlpath = get_safe_mat_export_name_for_obj(mat, object_name)
			#dprint.write('Saving override material with mtlpath <%s>' % [ mat_override_mtlpath ], 'save_meshes_to_obj')
			save_material_png(
					mat,
					object_name,
					tb_game_dir.usemtl_to_global(mat_override_mtlpath) + '.png')
			commit_mtlpath(mat_override_mtlpath, mat.resource_path)
		else:
			# Also handle non overriden mesh here, now that mesh info array has other stuff
			mat = null
			mat_mtlpath = ''
			mat_override = false

		# Check for offset (@NOTE: done earlier in pipeline now)
		if mesh_item[MESHINFO.OFFSET] is Vector3:
			offset = mesh_item[MESHINFO.OFFSET]
		else:
			offset = Vector3.ZERO

		mesh_surf_count = mesh.get_surface_count()

		# Info comment
		obj.comment('Mesh %s' % [ prefix.substr(1, 5) ])

		if separate_objects:
			obj.object('%s_%s' % [ mesh.get_name(), mesh_idx ])

		for surf_idx in range(mesh_surf_count):
			_emit_progress(mesh_idx, surf_idx, indicies_commit, -1)
			yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

			#region Partially moved to MeshUtils, finish
			var surface = mesh.surface_get_arrays(surf_idx)

			# @TODO: Probably should handle these before obj building
			if surface[ArrayMesh.ARRAY_INDEX] == null:
				var st := SurfaceTool.new()
				st.create_from(mesh, surf_idx)
				st.index()

				surface = st.commit().surface_get_arrays(0)

				if surface[ArrayMesh.ARRAY_INDEX] == null:
					dprint.warn("Failed to convert non-indexed surface to indexed for object %s, mesh %s, surface #%d" % [
								surf_idx,
								mesh.get_name(),
								object_name
							], 'save_meshes_to_obj')
					continue
			#endregion Partially moved to MeshUtils, finish

			obj.surface('mesh-' + str(surf_idx))

			# Use override if set
			if mat_override:
				mat_mtlpath = mat_override_mtlpath
			else:
				mat = mesh.surface_get_material(indicies_commit)
				mat_mtlpath = get_safe_mat_export_name_for_obj(mat, object_name)

				#dprint.write('   %s Saving material for %s' % [ prefix, mat_mtlpath ], 'save_meshes_to_obj')
				save_material_png(mat, object_name, tb_game_dir.usemtl_to_global(mat_mtlpath + '.png'))
				commit_mtlpath(mat_mtlpath, mat.resource_path)

			if mat == null:
				#dprint.write('   %s Using fallback material' % [ prefix ], 'save_meshes_to_obj')
				mat = mat_fallback

			#dprint.write('   %s Material: %s' % [
			#		prefix,
			#		("<Override:%s>" if mat_override else "%s") % mat_mtlpath ], 'save_meshes_to_obj')

			if len(mat_mtlpath) > 0:
				obj.material(tb_game_dir.usemtl_path(mat_mtlpath))
			else:
				dprint.warn('Reached usemtl expression with empty mat_mtlpath', 'save_meshes_to_obj')

			obj.process_verts(surface)


			#var has_uv = false
			#if surface[ArrayMesh.ARRAY_TEX_UV] != null:
			#	for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
			#		obj.uv(uv)
			#	has_uv = true
			obj.process_uv(surface)

			#var has_n = false
			#if surface[ArrayMesh.ARRAY_NORMAL] != null:
			#	for n in surface[ArrayMesh.ARRAY_NORMAL]:
			#		obj.normal(n)
			#	has_n = true
			obj.process_norm(surface)

			# Write triangle faces
			# Note: Godot's front face winding order is different from obj file format
			var i := 0
			var sig_i_count := i
			var indices = surface[ArrayMesh.ARRAY_INDEX]
			var surf_indicies_count = indices.size()

			var has_uv := obj.current_surface_has_uv()
			var has_norm := obj.current_surface_has_normal()
			while i < surf_indicies_count:
				# lmao
				obj.push(
					"f " +
						str(index_base + indices[i]) +
						("/" + str(index_base + indices[i]) if has_uv else "") +
						(
							(
								("/" if not has_uv else "") +
								("/" + str(index_base + indices[i]))
							) if has_norm else ""
						)
					+ " " +
						str(index_base + indices[i + 2]) +
						("/" + str(index_base + indices[i + 2]) if has_uv else "") +
						(
							(
								("/" if not has_uv else "") +
								("/" + str(index_base + indices[i + 2]))
							) if has_norm else ""
						)
					+ " " +
						str(index_base + indices[i + 1]) +
						("/" + str(index_base + indices[i + 1]) if has_uv else "") +
						(
							(
								("/" if not has_uv else "") +
								("/" + str(index_base + indices[i + 1]))
							) if has_norm else ""
						)
				)

				i += 3
				sig_i_count += 3

				if sig_i_count > progress_interval:
					sig_i_count = 0
					_emit_progress(mesh_idx, indicies_commit, i - 1 + indicies_commit, surf_indicies_count)
					yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)


			index_base += surface[ArrayMesh.ARRAY_VERTEX].size()

			indicies_commit += surf_indicies_count
			# - 1 required for off-by-one error in total at end for some reason
			_emit_progress(mesh_idx, surf_idx, indicies_commit - 1, surf_indicies_count)
			yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)


	dprint.write('Processed all meshes', 'save_meshes_to_obj')

	var write_err := write_file(obj_path, obj.get_file()) # output)
	if write_err != OK:
		emit_signal("export_failed", object_name)
		dprint.error('Export failed, error writing file %d' % [ write_err ], 'save_meshes_to_obj')
	else:
		emit_signal("export_success", object_name)
		dprint.write('Export successful', 'save_meshes_to_obj')

	emit_signal("export_completed", object_name)

	#if yield_and_process_if_cancelled(): return
	yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)


func check_and_handle_cancellation(ctx: String) -> bool:
	if cancelled:
		dprint.write('Export cancelled, exiting early and firing signal', ctx)
		emit_signal("export_cancelled", "<object_name>")
		return true

	return false

# Wrapper for pause (to allow gui to update) then cancellation check/handling. Will return true if
# cancellation initiated. Should be called during processing in base obj export function in addition
# to the batch processor before and after each item.
func yield_and_process_if_cancelled(ctx := 'save_meshes_to_obj') -> bool:
	if (not blocking):
		yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)
		#dprint.write('<YIELD-CHECK:%s>' % [ ctx ], 'yield_and_process_if_cancelled')
		return check_and_handle_cancellation(ctx)
	return false


# Update `cancelled` member to true, which when checked in main export loop will
# fire `export_cancelled` signal
# @TODO: Better to fire here or?
func cancel_export() -> void:
	if cancelled == true:
		dprint.warn('Exporter already cancelled.', 'cancel_export')
	cancelled = true


func resolve_spatialmat_albedo(mat: SpatialMaterial) -> Image:
	dprint.write(' -> %s' % [ mat ], 'resolve_spatialmat_albedo')
	# Save albedo tex if found
	var alb = mat.get_texture(SpatialMaterial.TEXTURE_ALBEDO)
	if is_instance_valid(alb):
		#dprint.write('    -> Found albedo texture in base pass', 'resolve_spatialmat_albedo')
		return alb.get_data()
	else:
		pass
		#dprint.write('    SpatialMaterial has no albedo texture', 'resolve_spatialmat_albedo')

	# Check for shader albedo texture
	var color = mat.get('albedo_color')
	if color is Color:
		dprint.write('    -> Found albedo color in base pass', 'resolve_spatialmat_albedo')
		return image_from_color(color)
	else:
		#dprint.write('    SpatialMaterial has no albedo color', 'resolve_spatialmat_albedo')
		pass

	#dprint.write('    Failed to resolve albedo for SpatialMaterial', 'resolve_spatialmat_albedo')
	return null


func resolve_shadermat_albedo(mat: ShaderMaterial) -> Image:
	dprint.write(' -> ShaderMaterial', 'resolve_shadermat_albedo')
	# Save albedo tex if found
	var alb = mat.get_shader_param('albedoTex')
	if is_instance_valid(alb):
		#dprint.write('    -> Found albedo texture shader uniform in base pass', 'resolve_shadermat_albedo')
		return alb.get_data()
	else:
		#dprint.write('    SpatialMaterial has no albedo texture shader uniform', 'resolve_shadermat_albedo')
		pass

	# Check for shader albedo texture
	var color = mat.get_shader_param('albedo')
	if is_instance_valid(color):
		#dprint.write('    -> Found albedo color shader uniform in base pass', 'resolve_shadermat_albedo')
		return image_from_color(color)
	else:
		pass
		#dprint.write('    SpatialMaterial has no albedo color shader uniform', 'resolve_shadermat_albedo')

	#dprint.write('    Failed to resolve albedo for ShaderMaterial', 'resolve_shadermat_albedo')
	return null


# Search for an albedo in common places, and return it if found/generated
func resolve_mat_albedo(mat: Material) -> Image:
	var resolved := false
	var img: Image
	#dprint.write('Entering Material Checks', 'resolve_mat_albedo')
	if mat is SpatialMaterial:
		img = resolve_spatialmat_albedo(mat)
		resolved = true

	elif mat is ShaderMaterial:
		img = resolve_shadermat_albedo(mat)
		resolved = true

	if resolved:
		return img
	else:
		#dprint.write(' -> Default', 'resolve_mat_albedo')
		#dprint.write('    (Fallback solid color not implemented)', 'resolve_mat_albedo')
		return null


func image_from_color(color: Color, width := 128, height := 128) -> Image:
	assert(width > 0)
	assert(height > 0)
	var image = Image.new()
	image.create(width, height, false, Image.FORMAT_RGB8)

	image.lock()

	image.fill(color)

	image.unlock()
	return image


func save_material_png(mat: Material, obj_name: String, mat_path: String = "") -> int:
	if mat_path == "":
		# Save to textures subfolder in obj file directory
		mat_path = tb_game_dir.models_tex_dir.plus_file(
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
		dprint.error("Can't push new mtlpath/resource path relation, conflict detected.", 'commit_mtlpath')
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
		#dprint.write('Found existing mtlpath <%s> for material resource path <%s>' % [
		#			mtlpath, mat.resource_path
		#		], 'get_safe_mat_export_name_for_obj')
		return mtlpath

	var mtlpath = matpath.mat_mtl_basename_for_obj(mat, object_name)

	# If no conflict, return it
	if not check_conflict_mtlpath(mtlpath, mat.resource_path):
		dprint.write('<%s> defined with matching resource path, or not yet used.' % [ mtlpath ], 'get_safe_mat_export_name_for_obj')
		return mtlpath

	# Else begin incrementing on end until save name
	#dprint.write('Found existing texture resource registered under %s, iterating number prefixes until new one found' % [
	#			mtlpath], 'get_safe_mat_export_name_for_obj')
	var new_name = mtlpath
	var inc = 0
	while true:
		inc += 1
		new_name = '%s_%d' % [ object_name, inc ]
		dprint.write(' -> %s' % [ new_name ], 'get_safe_mat_export_name_for_obj')
		if not check_conflict_mtlpath(new_name, mat.resource_path):
			dprint.write('   => %s' % [ new_name ], 'get_safe_mat_export_name_for_obj')
			return new_name

	return "ok"


# (Assumes path is valid)
func write_file(path: String, content: String) -> int:
	var file: File = File.new()

	dprint.write('Opening file path for output: <%s>' % [ path ], 'write_file')

	var open_err := file.open(path, File.WRITE)
	if open_err != OK:
		dprint.warn('Error code %s opening output file <%s>' % [ open_err, path ], 'write_file')
		file.close()
		return open_err

	dprint.write('Saving constructed %s to <%s>' % [ path.get_extension(), path.get_extension() ], 'write_file')
	file.store_string(content)
	file.close()

	return OK


# Dump given mesh to obj file
func save_mesh_to_obj(mesh: Mesh, obj_path: String, object_name: String):
	save_meshes_to_obj([mesh], obj_path, object_name)


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
