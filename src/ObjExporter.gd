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
const MESH_INDEX_PROGRESS_INTERVAL := 100
const DATA_FMT := {
	OBJ   = "o %s\n",
	VERT  = "v %f %f %f\n",
	UV    = "vt %f %f\n",
	NORM  = "vn %f %f %f\n",
	GROUP = "g surface%s\n",
	MAT   = "usemtl %s\n",
	MTL_LIB = "mtllib %s\n"
}
const MESHINFO := ObjBuilder.MESHINFO


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


func _emit_progress(mesh_idx: int, surface_idx: int, vertex_idx: int, curr_surface_vertex_total: int):
	emit_signal("export_progress", mesh_idx, surface_idx, vertex_idx, curr_surface_vertex_total)
	#dprint.write("Progress: %s %s %s %s" % [ mesh_idx, surface_idx, vertex_idx, vertex_total ])


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
	var mat_override:    bool = false
	var mat_mtlpath:     String
	var mat_override_mtlpath: String
	var prefix:          String
	var offset:          Vector3 = Vector3.ZERO
	# Used to track total over multiple surfaces
	var vert_commit := 0

	emit_signal("export_started", object_name, mesh_count)

	if not separate_objects:
		output += DATA_FMT.OBJ % [ object_name ]

	for mesh_item in meshes:
		mesh_idx += 1
		_emit_progress(mesh_idx, 0, vert_commit, -1)
		#if yield_and_process_if_cancelled(): return

		prefix = '[%02d/%02d]' % [ mesh_idx + 1, mesh_count ]
		dprint.write(' - %s Processing Mesh'   % [ prefix ], 'save_meshes_to_obj')

		# If extended data tuple
		if typeof(mesh_item) == TYPE_ARRAY:
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

			# Check for offset
			if mesh_item[MESHINFO.OFFSET] is Vector3:
				offset = mesh_item[MESHINFO.OFFSET]
			else:
				offset = Vector3.ZERO

		# Legacy meshes array content, don't think its used anywhere else now so get rid of it
		else:
			assert(mesh_item is Mesh)
			mesh = mesh_item.duplicate() as Mesh
			mat  = null
			mat_mtlpath = ''
			mat_override = false

		mesh_surf_count = mesh.get_surface_count()
		#dprint.write('   %s Surface Count: %s' % [ prefix, mesh_surf_count ], 'save_meshes_to_obj')

		# Info comment
		output += '# Mesh %s\n' % [ prefix.substr(1, 5) ]
		if separate_objects:
			output += DATA_FMT.OBJ % [ '%s_%s' % [ mesh.get_name(), mesh_idx ] ]

		var surface_vert_count: int
		for s in range(mesh_surf_count):
			_emit_progress(mesh_idx, s, vert_commit, -1)
			#if yield_and_process_if_cancelled(): return
			yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

			var surface = mesh.surface_get_arrays(s)

			# @TODO: Probably should handle these before obj building
			if surface[ArrayMesh.ARRAY_INDEX] == null:
				dprint.warn("Surface #%d on mesh %s of object %s is non-indexed, attempting indexing." % [ s, mesh.get_name(), object_name ], 'save_meshes_to_obj')

				var st := SurfaceTool.new()
				st.create_from(mesh, s)
				st.index()
				surface = st.commit().surface_get_arrays(0)

				if surface[ArrayMesh.ARRAY_INDEX] == null:
					dprint.warn("   -> Indexing failed.", 'save_meshes_to_obj')
					continue


			surface_vert_count = surface[ArrayMesh.ARRAY_INDEX].size()
			#dprint.write('   %s Vert Count:    %s' % [ prefix, surface_vert_count ], 'save_meshes_to_obj')

			output += DATA_FMT.GROUP % [ 'mesh-' + str(s) ]

			# Use override if set
			if mat_override:
				mat_mtlpath = mat_override_mtlpath
			else:
				mat = mesh.surface_get_material(s)
				mat_mtlpath = get_safe_mat_export_name_for_obj(mat, object_name)

				#dprint.write('   %s Saving material for %s' % [ prefix, mat_mtlpath ], 'save_meshes_to_obj')
				save_material_png(mat, object_name, tb_game_dir.usemtl_to_global(mat_mtlpath + '.png'))
				commit_mtlpath(mat_mtlpath, mat.resource_path)

			if mat == null:
				#dprint.write('   %s Using fallback material' % [ prefix ], 'save_meshes_to_obj')
				mat = mat_fallback

			dprint.write('   %s Material: %s' % [
					prefix,
					("<Override:%s>" if mat_override else "%s") % mat_mtlpath ], 'save_meshes_to_obj')

			if len(mat_mtlpath) > 0:
				output += DATA_FMT.MAT % [ tb_game_dir.usemtl_path(mat_mtlpath) ]
			else:
				dprint.warn('Reached usemtl expression with empty mat_mtlpath', 'save_meshes_to_obj')

			for v in surface[ArrayMesh.ARRAY_VERTEX]:
				output += DATA_FMT.VERT % [ v.x, v.y, v.z ]
				#output += DATA_FMT.VERT % [ str(v.x), str(v.y), str(v.z) ]
				#output += "v " + str(v.x) + " " + str(v.y) + " " + str(v.z) + "\n"

			var has_uv = false
			if surface[ArrayMesh.ARRAY_TEX_UV] != null:
				for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
					output += DATA_FMT.UV % [ uv.x, uv.y ]
					#output += DATA_FMT.UV % [ str(uv.x), str(uv.y) ]
					#output += "vt " + str(uv.x) + " " + str(uv.y) + "\n"
				has_uv = true

			var has_n = false
			if surface[ArrayMesh.ARRAY_NORMAL] != null:
				for n in surface[ArrayMesh.ARRAY_NORMAL]:
					output += DATA_FMT.NORM % [ n.x, n.y, n.z ]
					#output += DATA_FMT.NORM % [ str(n.x), str(n.y), str(n.z) ]
					#output += "vn " + str(n.x) + " " + str(n.y) + " " + str(n.z) + "\n"
				has_n = true

			# Write triangle faces
			# Note: Godot's front face winding order is different from obj file format
			var i := 0
			var sig_i_count := i
			var indices = surface[ArrayMesh.ARRAY_INDEX]
			var indicies_count = indices.size()
			while i < indicies_count:

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
				sig_i_count += 3

				if sig_i_count > MESH_INDEX_PROGRESS_INTERVAL:
					sig_i_count = 0
					_emit_progress(mesh_idx, s, i + vert_commit, indicies_count)
					#dprint.write('%2d / %2d / %2.2f' % [ mesh_idx + 1, s, float(float(i) / float(indicies_count)) ], 'save_meshes_to_obj')

					# if yield_and_process_if_cancelled(): return
					yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

			index_base += surface[ArrayMesh.ARRAY_VERTEX].size()

			#if yield_and_process_if_cancelled(): return
			yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

			vert_commit += surface_vert_count

	_emit_progress(mesh_count, mesh_surf_count, vert_commit, -1)
	#if yield_and_process_if_cancelled(): return
	yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

	dprint.write('Processed all meshes.', 'save_meshes_to_obj')

	var write_err := write_file(obj_path, output)
	if write_err != OK:
		emit_signal("export_failed", object_name)
		dprint.error('Export failed, error writing file %d' % [ write_err ], 'save_meshes_to_obj')
	else:
		emit_signal("export_success", object_name)
		dprint.write('Export complete.', 'save_meshes_to_obj')

	#if yield_and_process_if_cancelled(): return
	yield(scene_tree.create_timer(YIELD_DURATION), YIELD_METHOD)

	emit_signal("export_completed", object_name)


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
	dprint.write(' -> SpatialMaterial', 'resolve_spatialmat_albedo')
	# Save albedo tex if found
	var alb = mat.get_texture(SpatialMaterial.TEXTURE_ALBEDO)
	if is_instance_valid(alb):
		#dprint.write('    -> Found albedo texture in base pass', 'resolve_spatialmat_albedo')
		return alb.get_data()
	else:
		pass
		#dprint.write('    SpatialMaterial has no albedo texture', 'resolve_spatialmat_albedo')

	# Check for shader albedo texture
	var color = mat.albedo_color
	if is_instance_valid(color):
		#dprint.write('    -> Found albedo color in base pass', 'resolve_spatialmat_albedo')
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


func image_from_color(color: Color, width := 128, height := 129) -> Image:
	var image = Image.new()
	image.create(128, 128, false, Image.FORMAT_BPTC_RGBA)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, color)
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
