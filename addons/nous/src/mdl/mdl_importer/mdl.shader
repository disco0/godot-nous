shader_type spatial;
render_mode skip_vertex_transform
	, cull_disabled
	// , ambient_light_disabled
	;
// render_mode unshaded;

//----------------------------------------------------------------------

uniform vec3      scale = vec3(1, 1, 1);
uniform vec3      translate = vec3(0, 0, 0);
//uniform float     size = 1.0;
uniform int       start_frame = 0;
uniform int       end_frame = 0;
uniform bool      psx_quantize = false;
uniform float     psx_quantize_snap: hint_range(1, 200, 1) = 50.0;
uniform bool      interpolate = true;
uniform bool      wraparound = true;
uniform bool      automate = true;
uniform float     fps : hint_range(0, 60) = 10;
uniform float     anim_offset : hint_range(0, 1) = 0;
uniform int       num_skins : hint_range(1, 256) = 1;
uniform int       skin_index : hint_range(0, 255) = 0;
uniform sampler2D skin_texture;// : hint_albedo;
uniform sampler2D vertex_texture;// : hint_albedo;
uniform sampler2D normal_texture;// : hint_albedo;

varying vec4 vert_coord;

const float INV_255 = (1.0) / (255.0);

//----------------------------------------------------------------------

int get_vertex_index(vec4 color)
{
	int r8 = int(trunc(color.r * 255.0));
	int g8 = int(trunc(color.g * 255.0));
	int b8 = int(trunc(color.b * 255.0));
	int a8 = 0; // int(trunc(color.5 * 255.0));
	int index = r8 + (g8 << 8) + (b8 << 16) + (a8 << 24);
	return index;
}

float get_anim_pos(float time)
{
	float anim_pos = 0.0;
	int num_frames = end_frame - start_frame;
	if ((num_frames > 0) && automate)
	{
		anim_pos = fract(time * fps / float(num_frames));
	}
	return anim_pos;
}

float get_anim_frame(float anim_pos)
{
	int num_frames = end_frame - start_frame;
	float frame = float(start_frame);
	frame += (float(num_frames) + 0.999) * anim_pos;
	return frame;
}

ivec2 get_uv1a(int x, int y)
{
	return ivec2(x, y);
}

ivec2 get_uv1b(int x, int y)
{
	if (y == end_frame)
	{
		if (wraparound)
			return ivec2(x, start_frame);
		else
			return ivec2(x, end_frame);
	}
	else
		return ivec2(x, y + 1);
	return ivec2(0, 0);
}

vec4 get_texel(sampler2D tex, ivec2 uv1, ivec2 uv2, float fraction)
{

	vec4 texel1 = texelFetch(tex, uv1, 0);
	vec4 texel2 = texelFetch(tex, uv2, 0);
	//if (interpolate)
	//{
	//	return get_texel2(tex, uv1, uv2, fraction);
	//}
	//else
	//{
	//	return get_texel1(tex, uv1);
	//}
	// float gamma = 1.0 / 2.2;
	// texel1 = pow(texel1, vec4(gamma));
	// texel2 = pow(texel2, vec4(gamma));
	return mix(texel1, texel2, fraction);
}

//----------------------------------------------------------------------

void vertex()
{

	int vtx = (int(UV2.x) * 256) + int(UV2.y);

	float anim_pos = get_anim_pos(TIME);
	float frame = get_anim_frame(anim_pos + anim_offset);
	int iframe = int(trunc(frame));
	float fframe = fract(frame);
	ivec2 uv1a = get_uv1a(vtx, iframe);
	ivec2 uv1b = get_uv1b(vtx, iframe);

	vec3 pos = get_texel(vertex_texture, uv1a, uv1b, fframe).xyz;
	pos *= scale;
	pos += translate;

	vec3 normal = get_texel(normal_texture, uv1a, uv1b, fframe).xyz;
	normal = (normal * 2.0) - 1.0;

	pos *= 5.0;

	VERTEX = vec3(pos.x, pos.z, -pos.y);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (psx_quantize)
	{
		VERTEX.xyz = floor(VERTEX.xyz * psx_quantize_snap) / psx_quantize_snap;
	}
	vert_coord = vec4(UV * VERTEX.z, VERTEX.z, 0);
	NORMAL = vec3(normal.x, normal.z, -normal.y);
}

//----------

void fragment()
{
    //#region Original
	/* 

	float skin_scale = 1.0 / float(num_skins);
	float skin_offset = float(skin_index) * skin_scale;
	vec2 uv = vec2( UV.x, (UV.y * skin_scale) + skin_offset );
	vec4 c = texture(skin_texture, uv);
	ALBEDO = c.rgb;
	if (c.a < 0.5) discard;
	
	*/
    //#endregion Original

	float skin_scale = 1.0 / float(num_skins);
	float skin_offset = float(skin_index) * skin_scale;
	vec2 uv;
	if (psx_quantize)
	{
		uv = vec2(UV.x, (UV.y * skin_scale) + skin_offset);
	}
	else
	{
        // vec2 _uv = (vert_coord.xy / vert_coord.z).xy;
        // uv = vec2(_uv.x, (_uv.y * skin_scale) + skin_offset);
		uv = (vert_coord.xy / vert_coord.z).xy
		//c = texture(skin_texture, vert_coord.xy / vert_coord.z);
	}

	vec4 c = texture(skin_texture, uv);
	ALBEDO = c.rgb;

	if (c.a < 0.5)
		discard;
}