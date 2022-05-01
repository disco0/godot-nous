tool
class_name MdlHandRoll

# Type Equivalents:
# vec_t  => float
# vec3_t => vec_t[3] => Vector3


# http://tfc.duke.free.fr/coding/src/mdl.c#
# MDL model structure
class Model:
	# struct mdl_header_t header
	var header: MdlHeader

	# struct mdl_skin_t *skins;
	var skins: Array

	# struct mdl_texcoord_t *texcoords;
	var texcoords: Array

	# struct mdl_triangle_t *triangles;
	var triangles: Array

	# struct mdl_frame_t *frames;
	var frames: Array

	# GLuint *tex_id;
	var tex_id: PoolIntArray

	# int iskin;
	var iskin: int


# # Texture information
#
#   Texture data come right after the header in the file. It can be a texture composed of a single
# picture or a group of pictures (animated texture).
#
# Colormap: http://tfc.duke.free.fr/coding/src/colormap.h
#
# There are `num_skins` objects of `mdl_skin_t` type or `mdl_groupskin_t` type.


# Skin
class MdlSkin:
	var group: int

	# Texture Data
	var data: PoolByteArray


# Group of pictures
class MdlGroupSkin:
	# 1 = group
	var group: int = 1

	# number of pics
	var nb: int

	# time is an array of nb elements
	# (time duration for each pic)
	var time: Array

	# An array of nb arrays of skinwidth * skinheight elements (picture size)
	var ubyte: Array # Array<PoolByteArray> | PoolByteArray?


# # Texture coordinates
#
# Texture coordinates are stored in a structure as short integers.
#
# Texture are generally divided in two pieces: one for the frontface of the model, and one for the
# backface. The backface piece must be translated of skinwidth/2 from the frontface piece.
#
# To obtain real (s, t) coordinates (ranging from 0.0 to 1.0), you have to add 0.5 to the
# coordinates and then divide the result by skinwidth for s and skinheight for t.
#
# There are num_verts (s, t) texture coordinates in a MDL model. Texture coordinate data come after
# texture data.


class MdlTexCoord:
	# Indicates if the vertex is on the boundary of two pieces.
	var onseam: int

	var s: int

	var t: int

# # Triangles
#
# Each triangle has an array of vertex indices and a flag to indicate if it is a frontface or a
# backface triangle.
#
# If a vertex which belong to a backface triangle is on the boundary of two pieces (onseam is true),
# you have to add skinwidth/2 to s in order to correct texture coordinates.
#


# Triangle info
#struct mdl_triangle_t
class MdlTri:
	# 0 = backface, 1 = frontface
	var facesfront: int

	# vertex indices
	var vertex: Vector3


# # Vertices
#
# Vertices are composed of “compressed” 3D coordinates, which are stored in one byte for each
# coordinate, and of a normal vector index. The normal vector array is stored in the anorms.h file
# of Quake and hold 162 vectors in floating point (3 float).


# Compressed vertex
class MdlVertex:
	# unsigned char v[3];
	var v: PoolByteArray

	# unsigned char normalIndex;
	var normalIndex: int #?


# # Frames
#
# Each frames has its vertex list and some other specific informations.


# Simple frame
class MdlSimpleFrame:
	# bboxmin and bboxmax define a box in which the model can fit.
	# bouding box min
	var bboxmin: MdlVertex

	# bouding box max
	var bboxmax: MdlVertex

	# char name[16];
	# name is the name of the frame. verts is the vertex list of the frame.
	var name: PoolByteArray # [16];

	# struct mdl_vertex_t *verts
	# vertex list of the frame
	var verts: Array


# Frames can be simple frames or groups of frames. We can know if it's a simple frame or a group
# with a flag:


# Model frame
class MdlFrame:
	# 0 = simple, !0 = group
	var type: int

	# struct mdl_simpleframe_t frame;
	# this program can't read models composed of group frames!
	var frame: MdlSimpleFrame


# Group of simple frames
# `time` and `frames` are arrays of `nb` dimension. `min` and `max` correspond to the min and max
# positions in all simple frames of the frame group. `time` is the duration of each simple frame.
class MdlGroupFrame extends MdlFrame:
	# struct mdl_vertex_t min
	# min pos in all simple frames
	var _max: MdlVertex

	# struct mdl_vertex_t max
	# max pos in all simple frames
	var _min: MdlVertex

	# float *time
	# time duration for each frame
	var time: Array

	# !0 = group
	#var type: int

	# struct mdl_simpleframe_t frame;
	# this program can't read models composed of group frames!
	#var frame: MdlSimpleFrame
