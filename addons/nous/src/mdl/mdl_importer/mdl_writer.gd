tool

const MDL = MDLData.MDL

var mdl: MDLData
var out: StreamPeerBuffer

func _init(mdl: MDLData, out := StreamPeerBuffer.new()) -> void:
	self.mdl = mdl
	self.out = out

#region Write

func write(file_path: String):
	file = File.new()

	# @TODO: Overwrite check?
	# if not file.file_exists(file_path):
	# 	push_error("ERROR: file '" + file_path + "' does not exist")
	# 	return ERR_FILE_NOT_FOUND

	file.open(file_path, File.READ)

	write_header()
	skins = write_skins()
	texcoords = write_texcoords()
	triangles = write_triangles()
	frames = write_frames()

	file.close()
	return OK


func write_header() -> int:
	write_int(IDENT_MAGIC)
	write_int(header.version)
	write_vector(header.scale)
	write_vector(header.translate)
	write_float(header.bounding_radius)
	write_vector(header.eye_position)
	write_int(header.num_skins)
	write_int(header.skin_width)
	write_int(header.skin_height)
	write_int(header.num_verts)
	write_int(header.num_tris)
	write_int(header.num_frames)
	write_int(header.sync_type)
	write_int(header.flags)
	write_float(header.size)
	return OK


func write_skins() -> void:
	for i in range(header.num_skins):
		write_skin(skins[i])


func write_skin(skin: MDLSkin) -> void:
	write_int(skin.group)
	match skin.group:
		0: # MDLSkin
			write_byte_buffer(header.skin_width * header.skin_height)
		1: # MDLGroupSkin
			skin.group = 1
			skin.nb = write_int()
			skin.times = write_float_buffer(skin.nb)
			skin.data = write_byte_buffer(skin.nb * header.skin_width * header.skin_height)
			return skin
	return null


func write_byte() -> void:
	return file.put_8()


func write_int() -> int:
	return file.put_32()


func write_float() -> float:
	return file.put_float()


func write_vector() -> void:
	var x = file.put_float()
	var y = file.put_float()
	var z = file.put_float()
	var v = Vector3(x, y, z)
	return v


func write_vector8() -> void:
	var x = file.put_8()
	var y = file.put_8()
	var z = file.put_8()
	var v = Vector3(x, y, z)
	return v


func write_texcoord() -> void:
	var texcoord = MDL.MDLTexCoord.new()
	texcoord.on_seam = file.put_32()
	var s = file.put_32()
	var t = file.put_32()
	texcoord.uv = Vector2(s, t)
	return texcoord


func write_texcoords() -> void:
	var texcoords = Array()
	for i in range(header.num_verts):
		var texcoord = write_texcoord()
		texcoords.append(texcoord)
	return texcoords


func write_triangle() -> void:
	var triangle = MDL.MDLTriangle.new()
	triangle.front_facing = file.put_32() # == 1
	triangle.v1 = file.put_32()
	triangle.v2 = file.put_32()
	triangle.v3 = file.put_32()
	return triangle


func write_triangles() -> void:
	var triangles = Array()
	for i in range(header.num_tris):
		var triangle = write_triangle()
		triangles.append(triangle)
	return triangles


func write_simple_frame() -> void:
	var simpleframe = MDL.MDLSimpleFrame.new()
	simpleframe.type = 0
	simpleframe.bboxmin = write_vertex()
	simpleframe.bboxmax = write_vertex()
	simpleframe.name = write_string()
	simpleframe.verts = write_vertices()
	return simpleframe


func write_frame_group(frames) -> void:
	#var frames = Array()
	var num = write_int();
	#fg.type = num
	#fg.min_ = _write_vertex()
	#fg.max_ = _write_vertex()
	#var time_ = _write_float_buffer(num)
	var min_ = write_vertex()
	var max_ = write_vertex()
	var time_ = write_float_buffer(num)
	for i in range(num):
		var frame = write_simple_frame()
		#fg.frames.append(f)
		frames.append(frame)
	#return frames


func write_frames() -> void:
	var frames = Array()
	var num = header.num_frames
	for i in range(num):
		var type = write_int()
		if type == 0:
			var frame = write_simple_frame()
			frames.append(frame)
		else:
			write_frame_group(frames)
	return frames


func write_string(string: String, length: int = 16) -> void:
	file.put

func write_byte_buffer(b: PoolByteArray) -> void:
	file.put_buffer(b)


func write_float_buffer(size: PoolByteArray) -> void:
	file.put_buffer(data)


func write_vertex(vert: MDLVertex) -> void:
	write_vector8(vertex.pos)
	write_byte(vertex.normal)


func write_vertices() -> void:
	for i in range(header.num_verts):
		write_vertex(vertices[i])


#endregion Write
