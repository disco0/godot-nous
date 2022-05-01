tool
extends EditorImportPlugin

# Based on/modified from https://github.com/skei/godot-stuff/blob/main/mdl_importer/mdl_importer.gd


enum Presets { DEFAULT }


var mdl := MDLData.new()


func get_importer_name():
	return "mdl_importer"


func get_visible_name():
	return "mdl"


func get_recognized_extensions():
	return ["mdl"]


func get_save_extension():
	return "tres"


func get_resource_type():
	return "ArrayMesh"


func get_preset_count():
	return Presets.size()


func get_preset_name(preset):
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"


func get_import_options(preset: int):
	match preset:
		Presets.DEFAULT:
			return [
				{
					"name" : "import_as",
					"default_value" : "scene",
					"property_hint" : PROPERTY_HINT_ENUM,
					"hint_string" : "scene,mesh"
					#"usage" : "" # optional
				},
				{
					"name" : "frame",
					"default_value" : 0
					#"property_hint" : PROPERTY_HINT_NONE # optional
					#"hint_string" : "2" # optional
					#"usage" : "" # optional
				},
				{
					"name" : "skin",
					"default_value" : 0
					#"property_hint" : PROPERTY_HINT_NONE # optional
					#"hint_string" : "2" # optional
					#"usage" : "" # optional
				},
				{
					"name" : "palette",
					"default_value" : "quake",
					"property_hint" : PROPERTY_HINT_ENUM,
					"hint_string" : "quake,hexen"
					#"usage" : "" # optional
				}
				# {
				# 	"name" : "export_files",
				# 	"default_value" : false
				# 	#"property_hint" : PROPERTY_HINT_NONE # optional
				# 	#"hint_string" : "2" # optional
				# 	#"usage" : "" # optional
				# }
			]
		_:
			return []


func get_option_visibility(option, options):
	return true


func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	mdl.read(source_file,options.palette)
	var name = source_file.get_basename()
	#var scene = get_scene(name,options.frame,options.skin)
	var mesh = mdl.get_array_mesh(options.frame)
	var material = mdl.get_material(options.skin)
	mesh.surface_set_name(0,name)
	mesh.surface_set_material(0,material)

	print("Imported mdl:\n%s" % [ mdl ])
	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], mesh)


func get_description() -> String:
	var out := PoolStringArray([
		"scale: [ %s ]" % [ str(mdl.scale).lstrip('(').rstrip(')') ],
		"translate: [ %s ]" % [ str(mdl.translate).lstrip('(').rstrip(')') ],
		"bounding_radius : " + str(mdl.bounding_radius),
		"eye_position: [ %s ]" % [ str(mdl.eye_position).lstrip('(').rstrip(')') ],
		"num_skins: " + str(mdl.num_skins),
		"skin_width: " + str(mdl.skin_width),
		"skin_height: " + str(mdl.skin_height),
		"num_verts: " + str(mdl.num_verts),
		"num_tris: " + str(mdl.num_tris),
		"num_frames: " + str(mdl.num_frames),
		"sync_type: " + str(mdl.sync_type),
		"flags: " + str(mdl.flags),
		"size : " + str(mdl.size),
		"frames...",
	])

	var frames := ''
	for f in range(mdl.num_frames):
		frames += str(f) + ": " + mdl.frames[f].name + " "

	out.push_back(frames)
	return out.join('\n')


func get_mesh_instance(frame,skin):
	var material = mdl.get_material(skin)
	var mesh = mdl.get_array_mesh(frame)
	#mesh.surface_set_name(0,"mdl shader")
	#mesh.surface_set_material(0,material)
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_material(0,material)
	#mesh_instance.rotation.x = -PI / 2.0
	#mesh_instance.extra_cull_margin = 1.0
	mesh_instance.editor_description = get_description()
	return mesh_instance


func get_scene(name,frame,skin):
	var mesh_instance = get_mesh_instance(frame,skin)
	var scene = PackedScene.new()
	scene.pack(mesh_instance)
	return scene


#region Originals


#func load(path,original_path):
#	print("load: " + path + " / " + original_path)
#	read(path)
#	var mesh = get_array_mesh(0)
#	var material = get_material(0)
#	mesh.surface_set_name(0,"material_name")
#	mesh.surface_set_material(0,material)
#	return mesh

# https://github.com/victorfeitosa/quake-hexen2-mdl-export-import/blob/master/import_mdl.py

#def merge_frames(mdl):
#    def get_base(name):
#        i = 0
#        while i < len(name) and name[i] not in "0123456789":
#            i += 1
#        return name[:i]
#
#    i = 0
#    while i < len(mdl.frames):
#        if mdl.frames[i].type:
#            i += 1
#            continue
#        base = get_base(mdl.frames[i].name)
#        j = i + 1
#        while j < len(mdl.frames):
#            if mdl.frames[j].type:
#                break
#            if get_base(mdl.frames[j].name) != base:
#                break
#            j += 1
#        f = MDL.Frame()
#        f.name = base
#        f.type = 1
#        f.frames = mdl.frames[i:j]
#        mdl.frames[i:j] = [f]
#        i += 1


#class mdl_header:
	#var identifier						# magic number: "IDPO"
	#var version							# version: 6
	#var scale			= Vector3()		# scale factor
	#var translate		= Vector3()		# translation vector
	#var bounding_radius					#
	#var eye_position	= Vector3()		# eyes' position
	#var num_skins						# number of textures
	#var	skin_width						# texture width
	#var skin_height						# texture height
	#var num_verts						# number of vertices
	#var num_tris						# number of triangles
	#var num_frames						# number of frames
	#var sync_type						# 0 = synchron, 1 = random
	#var flags							# state flag
	#var size							#

#class mdl_skin:
	#var group				# 0 = single, 1 = group
	#var data				# texture data

#class mdl_groupskin:
	#var group				# 1 = group
	#var nb					# number of pics
	#var time				# time duration for each pic
	#var data				# texture data

#class mdl_texcoord:
	#var on_seam				#
	#var uv = Vector2()		#

#class mdl_triangle:
	#var front_facing		# 0 = backface, 1 = frontface
	#var v1					# vertex indices
	#var v2					#
	#var v3					#

#class mdl_vertex:
	#var pos = Vector3()		#
	#var normal				#

#class mdl_simpleframe:
	#var type				# 0 = simple
	#var bboxmin				# bounding box min
	#var bboxmax				# bounding box max
	#var name = String()		# char name[16]
	#var verts				# vertex list of the frame

#class mdl_framegroup:
	#var type				# !0 = group
	#var min_				# min pos in all simple frames
	#var max_				# max pos in all simple frames
	#var time = Array()		# time duration for each frame
	#var frames = Array()	# simple frame list

#----------------------------------------------------------------------

#const mdl_quake_palette = [
	#"#000000","#0f0f0f","#1f1f1f","#2f2f2f","#3f3f3f","#4b4b4b","#5b5b5b","#6b6b6b",
	#"#7b7b7b","#8b8b8b","#9b9b9b","#ababab","#bbbbbb","#cbcbcb","#dbdbdb","#ebebeb",
	#"#0f0b07","#170f0b","#1f170b","#271b0f","#2f2313","#372b17","#3f2f17","#4b371b",
	#"#533b1b","#5b431f","#634b1f","#6b531f","#73571f","#7b5f23","#836723","#8f6f23",
	#"#0b0b0f","#13131b","#1b1b27","#272733","#2f2f3f","#37374b","#3f3f57","#474767",
	#"#4f4f73","#5b5b7f","#63638b","#6b6b97","#7373a3","#7b7baf","#8383bb","#8b8bcb",
	#"#000000","#070700","#0b0b00","#131300","#1b1b00","#232300","#2b2b07","#2f2f07",
	#"#373707","#3f3f07","#474707","#4b4b0b","#53530b","#5b5b0b","#63630b","#6b6b0f",
	#"#070000","#0f0000","#170000","#1f0000","#270000","#2f0000","#370000","#3f0000",
	#"#470000","#4f0000","#570000","#5f0000","#670000","#6f0000","#770000","#7f0000",
	#"#131300","#1b1b00","#232300","#2f2b00","#372f00","#433700","#4b3b07","#574307",
	#"#5f4707","#6b4b0b","#77530f","#835713","#8b5b13","#975f1b","#a3631f","#af6723",
	#"#231307","#2f170b","#3b1f0f","#4b2313","#572b17","#632f1f","#733723","#7f3b2b",
	#"#8f4333","#9f4f33","#af632f","#bf772f","#cf8f2b","#dfab27","#efcb1f","#fff31b",
	#"#0b0700","#1b1300","#2b230f","#372b13","#47331b","#533723","#633f2b","#6f4733",
	#"#7f533f","#8b5f47","#9b6b53","#a77b5f","#b7876b","#c3937b","#d3a38b","#e3b397",
	#"#ab8ba3","#9f7f97","#937387","#8b677b","#7f5b6f","#775363","#6b4b57","#5f3f4b",
	#"#573743","#4b2f37","#43272f","#371f23","#2b171b","#231313","#170b0b","#0f0707",
	#"#bb739f","#af6b8f","#a35f83","#975777","#8b4f6b","#7f4b5f","#734353","#6b3b4b",
	#"#5f333f","#532b37","#47232b","#3b1f23","#2f171b","#231313","#170b0b","#0f0707",
	#"#dbc3bb","#cbb3a7","#bfa39b","#af978b","#a3877b","#977b6f","#876f5f","#7b6353",
	#"#6b5747","#5f4b3b","#533f33","#433327","#372b1f","#271f17","#1b130f","#0f0b07",
	#"#6f837b","#677b6f","#5f7367","#576b5f","#4f6357","#475b4f","#3f5347","#374b3f",
	#"#2f4337","#2b3b2f","#233327","#1f2b1f","#172317","#0f1b13","#0b130b","#070b07",
	#"#fff31b","#efdf17","#dbcb13","#cbb70f","#bba70f","#ab970b","#9b8307","#8b7307",
	#"#7b6307","#6b5300","#5b4700","#4b3700","#3b2b00","#2b1f00","#1b0f00","#0b0700",
	#"#0000ff","#0b0bef","#1313df","#1b1bcf","#2323bf","#2b2baf","#2f2f9f","#2f2f8f",
	#"#2f2f7f","#2f2f6f","#2f2f5f","#2b2b4f","#23233f","#1b1b2f","#13131f","#0b0b0f",
	#"#2b0000","#3b0000","#4b0700","#5f0700","#6f0f00","#7f1707","#931f07","#a3270b",
	#"#b7330f","#c34b1b","#cf632b","#db7f3b","#e3974f","#e7ab5f","#efbf77","#f7d38b",
	#"#a77b3b","#b79b37","#c7c337","#e7e357","#7fbfff","#abe7ff","#d7ffff","#670000",
	#"#8b0000","#b30000","#d70000","#ff0000","#fff393",
	##"#fff7c7","#ffffff","#9f5b53"
	#"#00000000","#00000000","#00000000"
#]

# hexen 2:
# https://github.com/victorfeitosa/quake-hexen2-mdl-export-import/blob/master/hexen2pal.py

#const mdl_hexen_palette = [
	#"#00000000","#000000","#080808","#101010","#181818","#202020","#282828","#303030",
	#"#383838","#404040","#484848","#505050","#545454","#585858","#606060","#686868",
	#"#707070","#787878","#808080","#888888","#949494","#9C9C9C","#A8A8A8","#B4B4B4",
	#"#B8B8B8","#C4C4C4","#CCCCCC","#D4D4D4","#E0E0E0","#E8E8E8","#F0F0F0","#FCFCFC",
	#"#08080C","#101014","#18181C","#1C2024","#24242C","#2C2C34","#30343C","#383844",
	#"#404048","#4C4C58","#5C5C68","#6C7080","#808498","#989CB0","#A8ACC4","#BCC4DC",
	#"#201814","#28201C","#302420","#342C28","#3C342C","#443834","#4C4038","#544840",
	#"#5C4C48","#64544C","#6C5C54","#706058","#786860","#807064","#88746C","#907C70",
	#"#141814","#1C201C","#202420","#282C28","#2C302C","#303830","#384038","#404440",
	#"#444C44","#545C54","#687068","#788078","#8C9488","#9CA498","#ACB4A8","#BCC4B8",
	#"#302008","#3C2808","#483010","#543814","#5C401C","#644824","#6C502C","#785C34",
	#"#88683C","#947448","#A08054","#A8885C","#B49064","#BC986C","#C4A074","#CCA87C",
	#"#101410","#141C14","#182018","#1C241C","#202C20","#243024","#283828","#2C3C2C",
	#"#304430","#344C34","#3C543C","#445C40","#4C6448","#546C4C","#5C7454","#64805C",
	#"#180C08","#201008","#281408","#34180C","#3C1C0C","#44200C","#4C2410","#542C14",
	#"#5C3018","#64381C","#704020","#784824","#80502C","#905C38","#A87048","#C08458",
	#"#180404","#240404","#300000","#3C0000","#440000","#500000","#580000","#640000",
	#"#700000","#840000","#980000","#AC0000","#C00000","#D40000","#E80000","#FC0000",
	#"#100C20","#1C1430","#201C38","#282444","#342C50","#3C385C","#444068","#504874",
	#"#585480","#64608C","#6C6C98","#7874A4","#8484B0","#9090BC","#9C9CC8","#ACACD4",
	#"#241404","#341804","#442004","#502800","#643004","#7C3C04","#8C4804","#9C5808",
	#"#AC6408","#BC740C","#CC800C","#DC9010","#ECA014","#FCB838","#F8C850","#F8DC78",
	#"#141004","#1C1808","#242008","#2C280C","#343010","#383810","#404014","#444818",
	#"#48501C","#505C20","#546828","#58742C","#5C8034","#5C8C34","#5C9438","#60A040",
	#"#3C1010","#481818","#541C1C","#642424","#702C2C","#7C3430","#8C4038","#984C40",
	#"#2C1408","#381C0C","#482010","#542814","#602C1C","#703420","#7C3828","#8C4030",
	#"#181410","#241C14","#2C241C","#382C20","#403424","#483C2C","#504430","#5C4C34",
	#"#64543C","#705C44","#786448","#847050","#907858","#988060","#A08868","#A89470",
	#"#24180C","#2C2010","#342814","#3C2C14","#483418","#503C1C","#58441C","#684C20",
	#"#946038","#A06C40","#AC7448","#B47C50","#C08458","#CC8C5C","#D89C6C","#3C145C",
	#"#642474","#A848A4","#CC6CC0","#045404","#048404","#00B400","#00D800","#040490",
	#"#1044CC","#2484E0","#58A8E8","#D80404","#F44800","#FC8000","#FCAC18","#FCFCFC"
#]

var mdl_palette

#endregion Originals
