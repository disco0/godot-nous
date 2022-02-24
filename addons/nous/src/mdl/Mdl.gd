class_name Mdl

# Type Equivalents:
# vec_t  => float
# vec3_t => vec_t[3] => Vector3

# https://www.gamers.org/dEngine/quake/spec/quake-spec34/qkspec_5.htm
# - The size of this header is 0x54 bytes (84).
class MdlHeader:
	# http://tfc.duke.free.fr/coding/mdl-specs-en.html
	#
	#	/* MDL header */
	#	struct mdl_header_t
	#	{
	#	  int ident;            /* magic number: "IDPO" */
	#	  int version;          /* version: 6 */
	#
	#	  vec3_t scale;         /* scale factor */
	#	  vec3_t translate;     /* translation vector */
	#	  float boundingradius;
	#	  vec3_t eyeposition;   /* eyes' position */
	#
	#	  int num_skins;        /* number of textures */
	#	  int skinwidth;        /* texture width */
	#	  int skinheight;       /* texture height */
	#
	#	  int num_verts;        /* number of vertices */
	#	  int num_tris;         /* number of triangles */
	#	  int num_frames;       /* number of frames */
	#
	#	  int synctype;         /* 0 = synchron, 1 = random */
	#	  int flags;            /* state flag */
	#	  float size;
	#	};

	#   `ident` is the magic number of the file. It is used to identify the file type. ident must be
	# equal to 1330660425 or to the string “IDPO”.
	#   We can obtain this number with the expression (('2'<<24) + ('P'<<16) + ('D'<<8) + 'I').
	var ident: int = ('O'.to_ascii()[0] << 24) + ('P'.to_ascii()[0] << 16) + ('D'.to_ascii()[0] << 8) + 'I'.to_ascii()[0]

	# version: 6
	var version: int

	#    scale and translate are needed to obtain the real vertex coordinates of the model. scale is
	# a scale factor and translate a translation vector (or the origin of the model). You have to
	# first multiply the respective value of scale with the vertex coordinate and then, add the
	# respective value of translate to the result:
	#
	#   vreal[i] = (scale[i] * vertex[i]) + translate[i];
	#
	# Where i ranges from 0 ou 2 (x, y and z coordinates).
	var scale: Vector3
	var translate: Vector3
	# boundingradius is the radius of a sphere in which the whole model can fit (used for collision
	# detection for exemple).
	var boundingradius: float
	# eyeposition is... eyes' position (if the model is for a monster or other NPC). Make what you
	# want of it.
	var eyeposition: Vector3

	# number of textures
	var num_skins: int
	# texture width
	var skinwidth: int
	# texture height
	var skinheight: int

	# Number of vertices of one frame.
	var num_verts: int
	# Number of triangles of the model
	var num_tris: int
	# Number of frames of the model
	var num_frames: int

	# 0 = synchron, 1 = random
	var synctype: int
	# state flag
	var flags: int
	var size: float

# # Texture information
#
#   Texture data come right after the header in the file. It can be a texture composed of a single
# picture or a group of pictures (animated texture).

# (Skin shadows built in type)
class MdlSkin:
	var group: int
