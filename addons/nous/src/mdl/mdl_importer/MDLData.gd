tool
class_name MDLData

const MDL := preload('./classes.gd')
const PALETTES := MDL.PALETTES
const INV_255 := MDL.INV_255
const IDENT_MAGIC := 0x4F504449
const MDL_VERSION := 6

var file: File
var file_path: String
var header := MDL.MDLHeader.new()
var mdl_palette: PoolColorArray

var skins := Array()
var texcoords := Array()
var triangles := Array()
var frames := Array()


#region Read

func read(file_path: String, palette: String):
	print("palette: " + palette)
	match palette:
		"hexen":
			mdl_palette = PALETTES[MDL.PALETTE_HEXEN]
		_:
			mdl_palette = PALETTES[MDL.PALETTE_QUAKE]

	file = File.new()
	if not file.file_exists(file_path):
		push_error("ERROR: file '" + file_path + "' does not exist")
		return ERR_FILE_NOT_FOUND

	file.open(file_path, File.READ)

	read_header()
	skins = read_skins()
	texcoords = read_texcoords()
	triangles = read_triangles()
	frames = read_frames()

	file.close()
	return OK


func read_header() -> int:
	var ident_byte := read_int()
	if ident_byte != IDENT_MAGIC:
		push_error("ERROR: wrong header.identifier %x (should be %x)" % [ ident_byte, IDENT_MAGIC ])
		return ERR_FILE_CORRUPT

	header.version = read_int()
	if header.version != MDL_VERSION:
		push_error("ERROR: wrong header.version %d (should be %d)" % [ header.version, MDL_VERSION ])
		return ERR_INVALID_DATA

	header.scale = read_vector()
	header.translate = read_vector() * INV_255
	header.bounding_radius = read_float() * INV_255
	header.eye_position = read_vector() * INV_255
	header.num_skins = read_int()
	header.skin_width = read_int()
	header.skin_height = read_int()
	header.num_verts = read_int()
	header.num_tris = read_int()
	header.num_frames = read_int()
	header.sync_type = read_int()
	header.flags = read_int()
	header.size = read_float()
	return OK


func read_skins():
	var skins = Array()
	for i in range(header.num_skins):
		var skin = read_skin()
		skins.append(skin)
	return skins


func read_skin():
	var group = read_int()
	match group:
		0: # single
			var skin = MDL.MDLSkin.new()
			skin.group = 0
			skin.data = read_byte_buffer(header.skin_width * header.skin_height)
			return skin
		1: # group
			var skin = MDL.MDLGroupSkin.new()
			skin.group = 1
			skin.nb = read_int()
			skin.times = read_float_buffer(skin.nb)
			skin.data = read_byte_buffer(skin.nb * header.skin_width * header.skin_height)
			return skin
	return null


func read_byte():
	return file.get_8()


func read_int() -> int:
	return file.get_32()


func read_float() -> float:
	return file.get_float()


func read_vector():
	var x = file.get_float()
	var y = file.get_float()
	var z = file.get_float()
	var v = Vector3(x, y, z)
	return v


func read_vector8():
	var x = file.get_8()
	var y = file.get_8()
	var z = file.get_8()
	var v = Vector3(x, y, z)
	return v


func read_texcoord():
	var texcoord = MDL.MDLTexCoord.new()
	texcoord.on_seam = file.get_32()
	var s = file.get_32()
	var t = file.get_32()
	texcoord.uv = Vector2(s, t)
	return texcoord


func read_texcoords():
	var texcoords = Array()
	for i in range(header.num_verts):
		var texcoord = read_texcoord()
		texcoords.append(texcoord)
	return texcoords


func read_triangle():
	var triangle = MDL.MDLTriangle.new()
	triangle.front_facing = file.get_32() # == 1
	triangle.v1 = file.get_32()
	triangle.v2 = file.get_32()
	triangle.v3 = file.get_32()
	return triangle


func read_triangles():
	var triangles = Array()
	for i in range(header.num_tris):
		var triangle = read_triangle()
		triangles.append(triangle)
	return triangles


func read_simple_frame():
	var simpleframe = MDL.MDLSimpleFrame.new()
	simpleframe.type = 0
	simpleframe.bboxmin = read_vertex()
	simpleframe.bboxmax = read_vertex()
	simpleframe.name = read_string()
	simpleframe.verts = read_vertices()
	return simpleframe


func read_frame_group(frames):
	#var frames = Array()
	var num = read_int();
	#fg.type = num
	#fg.min_ = _read_vertex()
	#fg.max_ = _read_vertex()
	#var time_ = _read_float_buffer(num)
	var min_ = read_vertex()
	var max_ = read_vertex()
	var time_ = read_float_buffer(num)
	for i in range(num):
		var frame = read_simple_frame()
		#fg.frames.append(f)
		frames.append(frame)
	#return frames


func read_frames():
	var frames = Array()
	var num = header.num_frames
	for i in range(num):
		var type = read_int()
		if type == 0:
			var frame = read_simple_frame()
			frames.append(frame)
		else:
			read_frame_group(frames)
	return frames


func read_string():
	var zero = false
	var s = String()
	for i in range(16):
		var c := file.get_8()
		if c == 0:
			zero = true
		if not zero:
			s += String("%c" % c)
	return s


func read_byte_buffer(size):
	var b = file.get_buffer(size)
	return b


func read_float_buffer(size):
	var data = file.get_buffer(size * 4)
	return data


func read_vertex() -> MDL.MDLVertex:
	var vertex := MDL.MDLVertex.new()
	vertex.pos = read_vector8()
	vertex.normal = read_byte()
	return vertex


func read_vertices():
	var vertices = Array()
	for i in range(header.num_verts):
		var vertex = read_vertex()
		vertices.append(vertex)
	return vertices


#endregion Read


#region Build

func calc_vertex_normals(frame_idx) -> Array:
	var vertices = frames[frame_idx].verts
	#var tri_normals = calc_tri_normals(frame)
	var vert_normals := []
	vert_normals.resize(header.num_verts)
	for v in range(header.num_verts):
		vert_normals[v] = Vector3()

	for t in range(header.num_tris):
		var tri = triangles[t]
		var v1 = vertices[tri.v1].pos
		var v2 = vertices[tri.v2].pos
		var v3 = vertices[tri.v3].pos
		var a = v3 - v1
		var b = v2 - v1
		var normal = a.cross(b)
		#normal = normal.normalized()
		vert_normals[tri.v1] += normal
		vert_normals[tri.v2] += normal
		vert_normals[tri.v3] += normal

	for v in range(header.num_verts):
		vert_normals[v] = vert_normals[v].normalized()
	return vert_normals


# x,y,z -> x,z,-y
func get_vertex_array(frame_idx: int):
	var vertices = PoolVector3Array()
	for i in range(header.num_tris):
		var i1 = triangles[i].v1;
		var i2 = triangles[i].v2;
		var i3 = triangles[i].v3;
		var v1 = frames[frame_idx].verts[i1].pos / 255.0
		var v2 = frames[frame_idx].verts[i2].pos / 255.0
		var v3 = frames[frame_idx].verts[i3].pos / 255.0

		v1 = ((v1 * header.scale) + header.translate)
		v2 = ((v2 * header.scale) + header.translate)
		v3 = ((v3 * header.scale) + header.translate)

		var temp
		temp = v1.y
		v1.y = v1.z
		v1.z = -temp
		temp = v2.y
		v2.y = v2.z
		v2.z = -temp
		temp = v3.y
		v3.y = v3.z
		v3.z = -temp

		vertices.push_back(v1 * 5.0)
		vertices.push_back(v2 * 5.0)
		vertices.push_back(v3 * 5.0)

	return vertices


func get_normal_array(frame: int) -> PoolVector3Array:
	var normals := PoolVector3Array()
	var vn := calc_vertex_normals(frame)
	for i in range(header.num_tris):
		var i1 = triangles[i].v1;
		var i2 = triangles[i].v2;
		var i3 = triangles[i].v3;
		var n1 = vn[i1]
		var n2 = vn[i2]
		var n3 = vn[i3]
		var temp

		temp = n1.y
		n1.y = n1.z
		n1.z = -temp

		temp = n2.y
		n2.y = n2.z
		n2.z = -temp

		temp = n3.y
		n3.y = n3.z
		n3.z = -temp

		normals.push_back(n1)
		normals.push_back(n2)
		normals.push_back(n3)
	return normals


func get_color_array() -> PoolColorArray:
	var colors := PoolColorArray()
	for i in range(header.num_tris):
		var c1 = Color(1, 0, 0)
		var c2 = Color(0, 1, 0)
		var c3 = Color(0, 0, 1)

		colors.push_back(c1)
		colors.push_back(c2)
		colors.push_back(c3)

	return colors


func get_texcoord1_array() -> PoolVector2Array:
	var skin_size := Vector2(header.skin_width, header.skin_height)
	var _texcoords := PoolVector2Array()
	for i in range(header.num_tris):
		var i1 = triangles[i].v1;
		var i2 = triangles[i].v2;
		var i3 = triangles[i].v3;
		var uv1 = texcoords[i1].uv / skin_size;
		var uv2 = texcoords[i2].uv / skin_size;
		var uv3 = texcoords[i3].uv / skin_size;

		if triangles[i].front_facing == 0:
			if texcoords[i1].on_seam > 0:
				uv1.x += 0.5;
			if texcoords[i2].on_seam > 0:
				uv2.x += 0.5;
			if texcoords[i3].on_seam > 0:
				uv3.x += 0.5;

		_texcoords.push_back(uv1)
		_texcoords.push_back(uv2)
		_texcoords.push_back(uv3)
	return _texcoords


func get_texcoord2_array() -> PoolVector2Array:
	var texcoords := PoolVector2Array()
	for i in range(header.num_tris):
		var i1 = (i * 3)
		var i2 = (i * 3) + 1
		var i3 = (i * 3) + 2
		var uv1 = Vector2((i1 & 0xff00) >> 8, i1 & 0x00ff)
		var uv2 = Vector2((i2 & 0xff00) >> 8, i2 & 0x00ff)
		var uv3 = Vector2((i3 & 0xff00) >> 8, i3 & 0x00ff)

		texcoords.push_back(uv1)
		texcoords.push_back(uv2)
		texcoords.push_back(uv3)

	return texcoords


func get_triangle_array() -> PoolIntArray:
	var triangles := PoolIntArray()
	for i in range(header.num_tris):
		var i1 = (i * 3)
		var i2 = (i * 3) + 1
		var i3 = (i * 3) + 2

		triangles.push_back(i1)
		triangles.push_back(i2)
		triangles.push_back(i3)

	return triangles


func get_image_from_skin(skin: int) -> Image:
	var image: Image = Image.new()
	var w = header.skin_width
	var h = header.skin_height
	var sd = skins[skin].data
	image.create(w, h, false, Image.FORMAT_RGBA8)
	image.lock()

	for y in range(h):
		for x in range(w):
			var i = y * w + x
			var c = sd[i]
			var col = mdl_palette[c]
			image.set_pixel(x, y, col)

	image.unlock()
	return image


func get_image_from_all_skins() -> Image:
	var image := Image.new()
	var w := header.skin_width
	var h := header.skin_height
	var sh = h * header.num_skins

	image.create(w, sh, false, Image.FORMAT_RGBA8)
	image.lock()

	for s in range(header.num_skins):
		var sd = skins[s].data
		for y in range(h):
			for x in range(w):
				var i = y * w + x
				var c = sd[i]
				var col := mdl_palette[c]
				image.set_pixel(x, (s*h)+y, col)

	image.unlock()
	return image


# we do the (x,y,z -> x,z,-y) transformation in the vertex shader
func get_image_from_vertices() -> Image:
	var image = Image.new()
	var w = header.num_tris * 3
	var h = header.num_frames

	image.create(w, h, false, Image.FORMAT_RGBAF)
	image.lock()

	for y in range(header.num_frames):
		var frame = frames[y]
		for x in range(header.num_tris):
			var i1 = triangles[x].v1;
			var i2 = triangles[x].v2;
			var i3 = triangles[x].v3;
			var v1 = frame.verts[i1].pos / 255.0
			var v2 = frame.verts[i2].pos / 255.0
			var v3 = frame.verts[i3].pos / 255.0
			var c1 = Color( v1.x, v1.y, v1.z, 1.0 )
			var c2 = Color( v2.x, v2.y, v2.z, 1.0 )
			var c3 = Color( v3.x, v3.y, v3.z, 1.0 )

			image.set_pixel((x*3)  , y, c1)
			image.set_pixel((x*3)+1, y, c2)
			image.set_pixel((x*3)+2, y, c3)

	image.unlock()
	return image


func get_image_from_normals() -> Image:
	var image = Image.new()
	var w = header.num_tris * 3
	var h = header.num_frames

	image.create(w, h, false, Image.FORMAT_RGBAF)
	image.lock()

	for y in range(header.num_frames):
		var normals := calc_vertex_normals(y)
		var frame = frames[y]

		for x in range(header.num_tris):
			var i1 = triangles[x].v1;
			var i2 = triangles[x].v2;
			var i3 = triangles[x].v3;
			var n1 = normals[i1]
			var n2 = normals[i2]
			var n3 = normals[i3]

			n1 = (n1 * 0.5) + Vector3(0.5, 0.5, 0.5)
			n2 = (n2 * 0.5) + Vector3(0.5, 0.5, 0.5)
			n3 = (n3 * 0.5) + Vector3(0.5, 0.5, 0.5)

			var c1 = Color( n1.x, n1.y, n1.z, 1.0 )
			var c2 = Color( n2.x, n2.y, n2.z, 1.0 )
			var c3 = Color( n3.x, n3.y, n3.z, 1.0 )

			image.set_pixel((x * 3),     y, c1)
			image.set_pixel((x * 3) + 1, y, c2)
			image.set_pixel((x * 3) + 2, y, c3)

	image.unlock()
	return image


func get_texture_from_image(image: Image) -> ImageTexture:
	var texture := ImageTexture.new()
	texture.create_from_image(image, 0)
	texture.flags = 0
	return texture


func get_texture_from_skin(skin: int) -> ImageTexture:
	var image := get_image_from_skin(skin)
	var texture := ImageTexture.new()
	texture.create_from_image(image, 0)
	texture.flags = 0
	return texture


func get_texture_from_all_skins() -> ImageTexture:
	var image := get_image_from_all_skins()
	var texture := ImageTexture.new()
	texture.create_from_image(image, 0)
	texture.flags = 0
	return texture


func get_shader() -> Shader:
	#var sha = Shader.new()
	#sha.code = mdl_shader
	var shader := preload("./mdl.shader")
	return shader


func get_material(skin):
	#var mat = SpatialMaterial.new()
	var material = ShaderMaterial.new()
	#var simg = create_image_from_skin(skin)
	var skin_img = get_image_from_all_skins()
	var vert_img = get_image_from_vertices()
	var norm_img = get_image_from_normals()
	var skin_tex = get_texture_from_image(skin_img)
	var vert_tex = get_texture_from_image(vert_img)
	var norm_tex = get_texture_from_image(norm_img)
	var shader = get_shader()
	material.shader = shader
	material.set_shader_param("scale", header.scale)
	material.set_shader_param("translate", header.translate)
	#material.set_shader_param("size",mdl_size)
	material.set_shader_param("start_frame", 0)
	material.set_shader_param("end_frame", header.num_frames - 1)
	material.set_shader_param("interpolate", true)
	material.set_shader_param("wraparound", true)
	if header.num_frames > 0:
		material.set_shader_param("automate", true)
	else:
		material.set_shader_param("automate", false)
	material.set_shader_param("fps", 10.0)
	material.set_shader_param("anim_offset", 0.0)
	material.set_shader_param("num_skins", header.num_skins)
	material.set_shader_param("skin_index", 0)
	material.set_shader_param("skin_texture", skin_tex)
	material.set_shader_param("vertex_texture", vert_tex)
	material.set_shader_param("normal_texture", norm_tex)
	#material.albedo_texture = stex
	return material


func get_array_mesh(frame):
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = get_vertex_array(frame)
	arrays[ArrayMesh.ARRAY_NORMAL] = get_normal_array(frame)
	arrays[ArrayMesh.ARRAY_COLOR] = get_color_array()
	arrays[ArrayMesh.ARRAY_TEX_UV] = get_texcoord1_array()
	arrays[ArrayMesh.ARRAY_TEX_UV2] = get_texcoord2_array()
	arrays[ArrayMesh.ARRAY_INDEX] = get_triangle_array()
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#var material = SpatialMaterial.new()
	#array_mesh.surface_set_material(0,material)
	return array_mesh


#endregion Build

#region Etc

func to_string() -> String:
	var out := PoolStringArray([
		"File:            %s"     % [ file_path ],
		"scale:           [ %s ]" % [ str(header.scale).lstrip('(').rstrip(')') ],
		"translate:       [ %s ]" % [ str(header.translate).lstrip('(').rstrip(')') ],
		"bounding_radius: %f"     % [ header.bounding_radius ],
		"eye_position:    [ %s ]" % [ str(header.eye_position).lstrip('(').rstrip(')') ],
		"num_skins:       %s"     % [ header.num_skins   ],
		"skin_width:      %s"     % [ header.skin_width  ],
		"skin_height:     %s"     % [ header.skin_height ],
		"num_verts:       %s"     % [ header.num_verts   ],
		"num_tris:        %s"     % [ header.num_tris    ],
		"num_frames:      %s"     % [ header.num_frames  ],
		"sync_type:       %s"     % [ header.sync_type   ],
		"flags:           %d"     % [ header.flags       ],
		"size:            %s"     % [ header.size        ],
		"frames:",
	])

	for f in range(header.num_frames):
		out.push_back("  %d: %s" %[ f, header.frames[f].name ])

	return out.join('\n')

#endregion Etc
